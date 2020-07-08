/***************************************************************************
 *cr
 *cr            (C) Copyright 1995-2016 The Board of Trustees of the
 *cr                        University of Illinois
 *cr                         All Rights Reserved
 *cr
 ***************************************************************************/
/***************************************************************************
 * RCS INFORMATION:
 *
 *      $RCSfile: pdbxplugin.C,v $
 *      $Author: johns $       $Locker:  $             $State: Exp $
 *      $Revision: 1.26 $       $Date: 2019/02/14 04:00:30 $
 ***************************************************************************
 * DESCRIPTION:
 *  A plugin for parsing and generating molecular model files that adhere 
 *  to the RCSB Protein Data Bank "PDBx" variant of the mmCIF file format, 
 *  as described here:
 *    http://mmcif.wwpdb.org/dictionaries/mmcif_pdbx_v50.dic/Index/
 *
 *  The plugin also incorporates experimental read-only support for 
 *  Integrative Hybrid Modeling (IHM) structure data in enhanced PDBx files:
 *    https://github.com/ihmwg/IHM-dictionary/blob/master/dictionary_documentation/documentation.md
 *
 ***************************************************************************/

#include "largefiles.h" /* platform dependent 64-bit file I/O defines */

#include "molfile_plugin.h"
#include "periodic_table.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if !(defined(WIN32) || defined(WIN64))
#include <sys/time.h>
#endif

#define VMDPLUGIN_STATIC
#include "inthash.h"

//#define PDBX_DEBUG 1

//used for reading author defined values needed when reading bond info
#define CHAIN_SIZE 4
#define TYPE_SIZE 8
#define BUFFER_SIZE 4096
#define COLUMN_BUFFER_SIZE 1024
#define MAX_COLUMNS 32

struct list_node
{
  unsigned int next;
  unsigned int index;
};

// class definition
typedef struct pdbxParser
{
  FILE *file;
  int *resid_auth;
  char *chain_auth;
  char *type_auth;
  float *xyz;
  int *bondsTo;
  int *bondsFrom;
  molfile_graphics_t *g_data;
  list_node *hashMem;
  inthash_t bondHash;
  int table[64];
  unsigned int tableSize;
  int natoms;
  int nbonds;
  int n_graphics_elems;
  bool error;
  bool pdb_dev;
} pdbxParser;

// XXX yuck, this needs to go!
static unsigned char charToNum[128];

enum TableColums
{
  COLUMN_ATOM_TYPE =0,
  COLUMN_NUMBER,
  COLUMN_NAME,
  COLUMN_TYPE,
  COLUMN_TYPE_AUTH,
  COLUMN_RESNAME,
  COLUMN_RESID,
  COLUMN_RESID_AUTH,
  COLUMN_INSERTION,
  COLUMN_X,
  COLUMN_Y,
  COLUMN_Z,
  COLUMN_OCCUPANCY,
  COLUMN_BFACTOR,
  COLUMN_CHARGE,
  COLUMN_CHAIN,
  COLUMN_CHAIN_AUTH,
  COLUMN_MODEL_NUM,
  COLUMN_JUNK
};

// Opens the file, finds the number of atoms, and allocates arrays
// Reads in and stores information from the file
static pdbxParser *create_pdbxParser(const char *filepath);

// Reads through the file and stores data
static int parseStructure(molfile_atom_t *atoms, int *optflags, pdbxParser *parser);

static bool readRMSDBonds(molfile_atom_t *atoms, pdbxParser *parser);
static bool readAngleBonds(molfile_atom_t *atoms, pdbxParser *parser);
static bool readBonds(molfile_atom_t *atoms, pdbxParser *parser);

// Parse through file and return the total number of atoms
// Will rewind the file to the start
// Returns -1 if the number of atoms cannot be found
static int parseNumberAtoms(pdbxParser *parser);

// returns true if str starts with "_atom_site."
static inline bool isAtomSite(char *str);

static inline bool isValidateRMSDBond(char *str);

// Assumes that str contains a single floating point number and
// returns it as a float. NO ERROR CHECKING
// Must be passed a null terminating string
// Wrote specifically to parse strings returned from getNextWord()
static float stringToFloat(char *str);

// Takes a string str and finds the next word starting from pos
// word must be allocated and suffiently large, does NO ERROR CHECKING
// After returning, word will contain the next word and pos will be updated
// to point to the current position in str
static void getNextWord(char *str, void *word, int &pos, int maxstrlen, int maxwordlen);

// Takes a string str and finds the next word starting from pos
// word must be allocated and suffiently large, does NO ERROR CHECKING
// After returning, word will contain the next word and pos will be updated
// to point to the current position in str */
static void skipNextWord(char *str, void *word, int &pos, int maxlen);

// Returns a unique int id for an atom based on the chain and resid
static inline int getUniqueResID(char *chainstr, int resid);

static void initCharToNum();

#define WB_SIZE 1024

#if 0 
static const char atomSiteHeader[] =
  "loop_\n"
  "_atom_site.group_PDB\n"
  "_atom_site.id\n"
  "_atom_site.type_symbol\n"
  "_atom_site.label_atom_id\n"
  "_atom_site.label_alt_id\n"
  "_atom_site.label_comp_id\n"
  "_atom_site.label_asym_id\n"
  "_atom_site.label_entity_id\n"
  "_atom_site.label_seq_id\n"
  "_atom_site.pdbx_PDB_ins_code\n"
  "_atom_site.Cartn_x\n"
  "_atom_site.Cartn_y\n"
  "_atom_site.Cartn_z\n"
  "_atom_site.occupancy\n"
  "_atom_site.B_iso_or_equiv\n"
  "_atom_site.Cartn_x_esd\n"
  "_atom_site.Cartn_y_esd\n"
  "_atom_site.Cartn_z_esd\n"
  "_atom_site.occupancy_esd\n"
  "_atom_site.B_iso_or_equiv_esd\n"
  "_atom_site.pdbx_formal_charge\n"
  "_atom_site.auth_seq_id\n"
  "_atom_site.auth_comp_id\n"
  "_atom_site.auth_asym_id\n"
  "_atom_site.auth_atom_id\n"
  "_atom_site.pdbx_PDB_model_num\n";
#endif

static const char atomSiteHeader[] =
    "loop_\n"
    "_atom_site.group_PDB\n"
    "_atom_site.id\n"
    "_atom_site.type_symbol\n"
    "_atom_site.label_atom_id\n"
    "_atom_site.label_alt_id\n"
    "_atom_site.label_comp_id\n"
    "_atom_site.label_asym_id\n"
    "_atom_site.label_entity_id\n"
    "_atom_site.label_seq_id\n"
    "_atom_site.pdbx_PDB_ins_code\n"
    "_atom_site.Cartn_x\n"
    "_atom_site.Cartn_y\n"
    "_atom_site.Cartn_z\n"
    "_atom_site.occupancy\n"
    "_atom_site.pdbx_formal_charge\n"
    "_atom_site.auth_asym_id\n";

typedef struct pdbxWriter
{
  FILE *fd;
  char writeBuf[WB_SIZE];
  char pdbName[256];
  int bufferCount;
  molfile_atom_t *atoms;
  const float *coordinates;
  int numatoms;
} pdbxWriter;

static void writeBuffer(pdbxWriter *writer);
static void writeIntro(pdbxWriter *writer);
static void write(const char *str, pdbxWriter *writer);
static void writeAtomSite(pdbxWriter *writer);
static void close(pdbxWriter *writer);
static pdbxWriter *create_pdbxWriter(const char *filename, int numAtoms);
static void addAtoms(const molfile_atom_t *atoms, int optflags, pdbxWriter *writer);
static void addCoordinates(const float *coords, pdbxWriter *writer);
static void writeFile(pdbxWriter *writer);

//
// class implementation
//
static pdbxParser *create_pdbxParser(const char *filepath)
{
  pdbxParser *parser = new pdbxParser;
  char buffer[BUFFER_SIZE];
  int numberAtoms;
  parser->xyz = NULL;
  parser->nbonds = 0;
  parser->hashMem = NULL;
  parser->chain_auth = NULL;
  parser->resid_auth = NULL;
  parser->type_auth = NULL;
  parser->error = false;
  parser->g_data = NULL;
  parser->bondsTo = NULL;
  parser->bondsFrom = NULL;
  parser->file = fopen(filepath, "r");
  parser->pdb_dev = false;
  parser->n_graphics_elems = 0;
  memset(buffer, 0, sizeof(buffer));
  if (!parser->file)
  {
    printf("pdbxplugin) cannot open file %s\n", filepath);
    parser->error = true;
    return parser;
  }
  if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
  {
    printf("pdbxplugin) cannot read file %s\n", filepath);
    parser->error = true;
    return parser;
  }

  // Find the number of atoms
  parser->natoms = parseNumberAtoms(parser);
  numberAtoms = parser->natoms;
  if (!parser->pdb_dev && parser->natoms <= 0)
  {
    printf("pdbxplugin) Could not get atom number\n");
    parser->error = true;
    return parser;
  }
  if (parser->natoms != 0)
  {
    initCharToNum();
    parser->xyz = new float[numberAtoms * 3];
    parser->hashMem = new list_node[numberAtoms + 1];
    parser->chain_auth = new char[numberAtoms * CHAIN_SIZE];
    parser->resid_auth = new int[numberAtoms];
    parser->type_auth = new char[numberAtoms * TYPE_SIZE];
  }
  return parser;
}

static void delete_pdbxParser(pdbxParser *parser)
{
  fclose(parser->file);
  if (parser->xyz != NULL)
  {
    delete[] parser->xyz;
    parser->xyz = NULL;
  }

  if (parser->hashMem != NULL)
  {
    delete[] parser->hashMem;
    parser->hashMem = NULL;
  }
  if (parser->chain_auth != NULL)
  {
    delete[] parser->chain_auth;
    parser->chain_auth = NULL;
  }
  if (parser->resid_auth != NULL)
  {
    delete[] parser->resid_auth;
    parser->resid_auth = NULL;
  }
  if (parser->type_auth != NULL)
  {
    delete[] parser->type_auth;
    parser->type_auth = NULL;
  }
  if (parser->g_data != NULL)
  {
    delete[] parser->g_data;
    parser->g_data = NULL;
  }
  if (parser->bondsTo != NULL)
  {
    free(parser->bondsTo);
    parser->bondsTo = NULL;
  }
  if (parser->bondsFrom != NULL)
  {
    free(parser->bondsFrom);
    parser->bondsFrom = NULL;
  }
  if (parser->natoms != 0)
  {
    inthash_destroy(&parser->bondHash);
  }
  delete parser;
}

static void skipNextWord(char *str, void *word, int &pos, int maxlen)
{
  // Handle case if we start at end of line
  if (pos > maxlen)
  {
    return;
  }
  if (str[pos] == '\0' || str[pos] == '\n')
  {
    return;
  }
  // move forward until we hit non-whitespace
  while (str[pos] == ' ' || str[pos] == '\t')
  {
    ++pos;
    if (pos > maxlen)
    {
      return;
    }
  }
  // increment pos until we hit a whitespace
  while (str[pos] != ' ' && str[pos] != '\t')
  {
    pos++;
    if (pos > maxlen)
    {
      return;
    }
  }
}

static bool isPDB_DevFile(pdbxParser *parser)
{
  char buffer[BUFFER_SIZE];
  int count = 0;
  rewind(parser->file);
  while (NULL != fgets(buffer, BUFFER_SIZE, parser->file))
  {
    if (NULL != strstr(buffer, "_ihm_"))
    {
      ++count;
    }
    if (count > 5)
    {
      // arbitrarly chosen number of occurences
      // chosen so one or two random _ihm_ strings in a regular pdb
      // doesn't cause us to interpret the file as a PDB-Dev.
      // Although even if we do, parsing should continue without issues.
      return true;
    }
  }
  rewind(parser->file);
  return false;
}

static void getNextWord(char *str, void *word, int &pos, int maxstrlen, int maxwordlen)
{
  char *w = (char *)word;
  int wordpos = 0;
  w[0] = '\0';
  if (pos >= maxstrlen)
  {
    return;
  }

  // Handle case if we start at end of line
  if (str[pos] == '\0' || str[pos] == '\n')
  {
    return;
  }

  // move forward until we hit non-whitespace
  while (str[pos] == ' ' || str[pos] == '\t')
  {
    if (++pos >= maxstrlen)
    {
      return;
    }
  }

  // XXX records can be broken across lines, which breaks all of the
  //     assumptions made within this parser, we're going to have to
  //     completely re-tool how parsing is done for the more general
  //     variants of mmCIF such as the IHM models

  //
  // XXX experimental handling of string columns
  //
#if 0
  // The parser must handle mmCIF files that have
  // rows/records containing strings that are delimited by 
  // the '\'' or '"' character, where the whitespace skipping
  // approach breaks.  When we encounter the start of a string,
  // we need to then walk to the end of the string rather than
  // proceeding normally with whitespace skipping.
  if (str[pos] == '\'') {
    int start = pos; // record index of first '\'' char...
    pos++; // advance to next char 

    // loop until we find the second '\'' char, or hit the end of the line
    while ((pos < maxstrlen) && (str[pos] != '\'')) {
      pos++;
    }
    int end = pos; // record index of second '\'' char...
    int len = end-start+1;

    char colbuf[1024];
    memset(colbuf, 0, sizeof(colbuf));
    memcpy(colbuf, str+start, len);
//printf("getNextWord(): s: %d e: %d len: %d, \"%s\"\n", start, end, len, colbuf);
    strncpy(w, colbuf, maxwordlen-1);
    
    ++pos; // Increment pos to point to first char that has not been read
    return;
  }
#endif

  // increment pos until we hit a whitespace
  while (str[pos] != ' ' && str[pos] != '\t')
  {
    w[wordpos++] = str[pos++];
    if (wordpos >= maxwordlen)
    {
      w[maxwordlen - 1] = '\0';
      return;
    }
    if (pos >= maxstrlen)
    {
      w[wordpos] = '\0';
    }
  }

  w[wordpos] = '\0';
  ++pos; // Increment pos to point to first char that has not been read
}

static float stringToFloat(char *str)
{
  bool neg = (str[0] == '-');
  unsigned int total = 0;
  unsigned pos = neg ? 1 : 0;
  unsigned int num = 0;
  unsigned int denom = 1;
  float retval;

  // calculate integer before the decimal
  while (str[pos] != '.')
  {
    total = (total * 10) + str[pos] - '0';
    ++pos;
  }
  ++pos;

  // Find the fraction representing the decimal
  while (str[pos] != '\0')
  {
    num = (num * 10) + str[pos] - '0';
    denom *= 10;
    ++pos;
  }

  retval = (float)total + (double)num / (double)denom;
  if (neg)
    retval *= -1;
  return retval;
}

static bool isStructureDataHeader(const char *strbuf)
{
  if (strstr(strbuf, "_atom_site.") != NULL)
  {
    return true;
  }
  if (strstr(strbuf, "_ihm_starting_model_coord.") != NULL)
  {
    return true;
  }
  return false;
}

static int parseNumberAtoms(pdbxParser *parser)
{
  char buffer[BUFFER_SIZE];
  char wordbuffer[BUFFER_SIZE];
  int numatoms = 0;
  int i;
  int tableSize = 0;
  bool valid_mmcif = true;
  bool column_exists[MAX_COLUMNS];
  for (i = 0; i < MAX_COLUMNS; i++)
    column_exists[i] = false;

  int base_word_size = 0; // position of first char of column name
                          // ex: base_name.column_name
                          //               ^

  if (isPDB_DevFile(parser))
  {
    printf("pdbxplugin) WARNING: this appears to be a PDB-Dev file. PDB-Dev file reading is experimental.\n");
    parser->pdb_dev = true;
  }

  if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
    return 0;

  // skip past junk at start of file, stop when we get to atomSite data
  while (!isStructureDataHeader(buffer))
  {
    // if this is true then we couldnt find the header. Maybe it has a different name in newer PDBx definitions?
    // When this was first written _atom_site was the only allowed name, which apparently is no longer true
    if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
      return 0;
  }

  base_word_size = (char *)memchr(buffer, '.', sizeof(buffer)) - buffer + 1;

  while (isStructureDataHeader(buffer))
  {
    sscanf(buffer + base_word_size, "%s", wordbuffer); // table is used in parseStructure too
    // assign integer values to each column
    if (0 == strcmp(wordbuffer, "group_PDB"))
    {   
      parser->table[tableSize] = COLUMN_ATOM_TYPE;
      column_exists[COLUMN_ATOM_TYPE] = true;
    }
    else if (0 == strcmp(wordbuffer, "id"))
    {
      parser->table[tableSize] = COLUMN_NUMBER;
      column_exists[COLUMN_NUMBER] = true;
    }
    else if (0 == strcmp(wordbuffer, "type_symbol"))
    {
      parser->table[tableSize] = COLUMN_NAME;
      column_exists[COLUMN_NAME] = true;
    }
    else if (0 == strcmp(wordbuffer, "label_comp_id") || (parser->pdb_dev && 0 == strcmp(wordbuffer, "comp_id")))
    {
      parser->table[tableSize] = COLUMN_RESNAME;
      column_exists[COLUMN_RESNAME] = true;
    }
    else if (0 == strcmp(wordbuffer, "label_asym_id") || (parser->pdb_dev && 0 == strcmp(wordbuffer, "asym_id")))
    {
      parser->table[tableSize] = COLUMN_CHAIN;
      column_exists[COLUMN_CHAIN] = true;
    }
    else if (0 == strcmp(wordbuffer, "auth_asym_id"))
    {
      parser->table[tableSize] = COLUMN_CHAIN_AUTH;
      column_exists[COLUMN_CHAIN_AUTH] = true;
    }
    else if (0 == strcmp(wordbuffer, "Cartn_x"))
    {
      parser->table[tableSize] = COLUMN_X;
      column_exists[COLUMN_X] = true;
    }
    else if (0 == strcmp(wordbuffer, "Cartn_y"))
    {
      parser->table[tableSize] = COLUMN_Y;
      column_exists[COLUMN_Y] = true;
    }
    else if (0 == strcmp(wordbuffer, "Cartn_z"))
    {
      parser->table[tableSize] = COLUMN_Z;
      column_exists[COLUMN_Z] = true;
    }
    else if (0 == strcmp(wordbuffer, "label_seq_id") || (parser->pdb_dev && 0 == strcmp(wordbuffer, "seq_id")))
    {
      parser->table[tableSize] = COLUMN_RESID;
      column_exists[COLUMN_RESID] = true;
    }
    else if (0 == strcmp(wordbuffer, "auth_seq_id"))
    {
      parser->table[tableSize] = COLUMN_RESID_AUTH;
      column_exists[COLUMN_RESID_AUTH] = true;
    }
    else if (0 == strcmp(wordbuffer, "pdbx_PDB_ins_code"))
    {
      parser->table[tableSize] = COLUMN_INSERTION;
      column_exists[COLUMN_INSERTION] = true;
    }
    else if (0 == strcmp(wordbuffer, "B_iso_or_equiv"))
    {
      parser->table[tableSize] = COLUMN_BFACTOR;
      column_exists[COLUMN_BFACTOR] = true;
    }
    else if (0 == strcmp(wordbuffer, "occupancy"))
    {
      parser->table[tableSize] = COLUMN_OCCUPANCY;
      column_exists[COLUMN_OCCUPANCY] = true;
    }
    else if (0 == strcmp(wordbuffer, "label_atom_id") || (parser->pdb_dev && 0 == strcmp(wordbuffer, "atom_id")))
    {
      parser->table[tableSize] = COLUMN_TYPE;
      column_exists[COLUMN_TYPE] = true;
    }
    else if (0 == strcmp(wordbuffer, "auth_atom_id"))
    {
      parser->table[tableSize] = COLUMN_TYPE_AUTH;
      column_exists[COLUMN_TYPE_AUTH] = true;
    }
    else if (0 == strcmp(wordbuffer, "pdbx_formal_charge"))
    {
      parser->table[tableSize] = COLUMN_CHARGE;
      column_exists[COLUMN_CHARGE] = true;
    }
    else if (0 == strcmp(wordbuffer, "pdbx_PDB_model_num"))
    {
      parser->table[tableSize] = COLUMN_MODEL_NUM;
      column_exists[COLUMN_MODEL_NUM] = true;
    }
    else
    {
      parser->table[tableSize] = COLUMN_JUNK;
    }
    
    
    // if this is true then we couldnt find the numatoms
    if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
      return 0;

    tableSize++;
  }

  // increment numatoms until we get to the end of the file
  while (buffer[0] != '#')
  {
    // if this is true then we couldnt find the numatoms
    if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
      return 0;
    ++numatoms;
  }

  rewind(parser->file);
  // Cut off any junk columns from the end of table

  i = tableSize;
  while (parser->table[--i] == COLUMN_JUNK)
  {
  }
  tableSize = i + 1;
  parser->tableSize = tableSize;

  if (numatoms == 0)
  {
    printf("pdbxplugin) Could not parse atom number from file\n");
    return 0;
  }

  if (!column_exists[COLUMN_NUMBER])
  {
    printf("pdbxplugin) WARNING: missing 'id' field.\n");
    valid_mmcif = false;
  }
  if (!column_exists[COLUMN_CHAIN_AUTH] && !parser->pdb_dev)
  {
    // PDB-Dev doesn't include any *auth* fields, so its not missing.
    printf("pdbxplugin) WARNING: missing 'auth_asym_id' field.\n");
    valid_mmcif = false;
  }
  if (!column_exists[COLUMN_CHAIN])
  {
    printf("pdbxplugin) WARNING: missing 'label_asym_id' field.\n");
    valid_mmcif = false;
  }
  if (!column_exists[COLUMN_TYPE])
  {
    printf("pdbxplugin) WARNING: missing 'label_atom_id' field.\n");
    valid_mmcif = false;
  }
  if (!column_exists[COLUMN_RESNAME])
  {
    printf("pdbxplugin) WARNING: missing 'label_comp_id' field.\n");
    valid_mmcif = false;
  }
  if (!column_exists[COLUMN_RESID])
  {
    printf("pdbxplugin) WARNING: missing 'label_seq_id' field.\n");
    valid_mmcif = false;
  }
  if (!column_exists[COLUMN_NAME])
  {
    printf("pdbxplugin) WARNING: missing 'type_symbol' field.\n");
    valid_mmcif = false;
  }

  if (!column_exists[COLUMN_X] || !column_exists[COLUMN_Y] || !column_exists[COLUMN_Z])
  {
    // This is still technically a valid mmCIF file, although at the time of this comment
    // the PDB reports 100% of PDBx files contain these fields.
    // Not sure what to do if they don't exist.
    printf("pdbxplugin) WARNING: coordinate fields not found.\n");
  }

  if (!valid_mmcif && !parser->pdb_dev)
  {
    // The documentation on pdb_dev requirements is not clear, but for mmCIF/PDBx files
    // there are clearly defined "required fields" for atom_site tables.
    // The checks we perform for those are not exhaustive, but the fields we don't check
    // are not currently read by this parser.
    printf("pdbxplugin) WARNING: this is not a valid PDBx/mmCIF file.\n");
  }

  return numatoms;
}

static void initCharToNum()
{
  int i;
  int j = 1;

  for (i = 0; i < 128; i++)
    charToNum[i] = -1;

  i = 'A';
  while (i <= 'Z')
    charToNum[i++] = j++;
  i = 'a';
  while (i <= 'z')
    charToNum[i++] = j++;
  i = '0';
  while (i <= '9')
    charToNum[i++] = j++;
}

// This attempts to generate a unique id based off the chain name and resid...
static inline int getUniqueResID(char *chainstr, int resid)
{
  int uid;
  int length = strlen(chainstr);
  // Assuming max length of chainstr is 3 chars
  //Each char can be respresented by <= 6 bits since only a-z, A-Z, and 0-9 are valid values (62 possible values)
  uid = 1 + charToNum[(int)chainstr[0]];
  uid <<= 6;

  if (length == 1)
  {
    uid <<= 12;
  }
  else if (length == 2)
  {
    uid += charToNum[(int)chainstr[1]];
    uid <<= 12;
  }
  else if (length == 3)
  {
    uid += charToNum[(int)chainstr[1]];
    uid = (uid << 6) + charToNum[(int)chainstr[2]];
    uid <<= 6;
  }

  // First 18 bits of uid dedicated to 3 letters of chainstr
  uid <<= 12;
  uid += (0xFFF & resid); //add 12 least significant bits of resid to fill the remaining 10 bits of uid

  return uid;
}

#define ATOM_TYPE 0
#define ATOM_RESNAME 1
#define ATOM_INSERTION 2
#define ATOM_CHAIN 3
#define MAX_OPTIONAL_AUTH_FIELDS 2

#define FLAG_CHAIN_LENGTH 0x01
#define FLAG_CHARGE 0x02
#define FLAG_INSERTION 0x04
#define FLAG_BFACTOR 0x08
#define FLAG_OCCUPANCY 0x10
#define FLAG_MODEL_NUM 0x20

static int parseStructure(molfile_atom_t *atoms, int *optflags, pdbxParser *parser)
{
  int i, count, atomdata, pos, idx, xyzcount;

  // VMD will use the PDBx atom "type" field rather than the "name" field,
  // unless we're directed to do otherwise, so that we get the expected
  // PDB-specific atom nomenclature in the name field, as needed by STRIDE
  // and other tools.
  int vmdatomnamefrompdbxname = (getenv("VMDATOMNAMEFROMPDBXNAME") != NULL);

  char buffer[BUFFER_SIZE];

  char atomtypebuffer[COLUMN_BUFFER_SIZE];
  char namebuffer[COLUMN_BUFFER_SIZE];
  char occupancybuffer[COLUMN_BUFFER_SIZE];
  char bfactorbuffer[COLUMN_BUFFER_SIZE];
  char chargebuffer[COLUMN_BUFFER_SIZE];
  char residbuffer[COLUMN_BUFFER_SIZE];
  char residAuthbuffer[COLUMN_BUFFER_SIZE];
  char chainbuffer[COLUMN_BUFFER_SIZE];
  char trash[COLUMN_BUFFER_SIZE];
  char xbuffer[COLUMN_BUFFER_SIZE];
  char ybuffer[COLUMN_BUFFER_SIZE];
  char zbuffer[COLUMN_BUFFER_SIZE];
  char model_num_buf[COLUMN_BUFFER_SIZE];
  void *columns[MAX_COLUMNS];

  memset(buffer, 0, sizeof(buffer));
  memset(atomtypebuffer, 0, sizeof(atomtypebuffer));
  memset(namebuffer, 0, sizeof(namebuffer));
  memset(occupancybuffer, 0, sizeof(occupancybuffer));
  memset(bfactorbuffer, 0, sizeof(bfactorbuffer));
  memset(chargebuffer, 0, sizeof(chargebuffer));
  memset(residbuffer, 0, sizeof(residbuffer));
  memset(residAuthbuffer, 0, sizeof(residAuthbuffer));
  memset(chainbuffer, 0, sizeof(chainbuffer));
  memset(trash, 0, sizeof(trash));
  memset(xbuffer, 0, sizeof(xbuffer));
  memset(ybuffer, 0, sizeof(ybuffer));
  memset(zbuffer, 0, sizeof(zbuffer));
  memset(model_num_buf, 0, sizeof(model_num_buf));
  memset(columns, 0, sizeof(columns));

  molfile_atom_t *atom = NULL;
  int badptecount = 0;
  int chargecount = 0;
  int occupancycount = 0;
  int bfactorcount = 0;
  unsigned char parseFlags = 0;
  chainbuffer[1] = '\0';
  chainbuffer[2] = '\0';
  int hashTemp = 0;
  int hashCount = 1;
  int head = 0;
  int chainAuthIdx = MAX_COLUMNS - 1, typeIdx = MAX_COLUMNS - 1, resnameIdx = MAX_COLUMNS - 1;
  int insertionIdx = MAX_COLUMNS - 1, typeAuthIdx = MAX_COLUMNS - 1;
#if (vmdplugin_ABIVERSION >= 20)
  int chainIdx = MAX_COLUMNS - 1;
#endif
  char *chainAuth = parser->chain_auth;
  char *typeAuth = parser->type_auth;
  int tableSize = parser->tableSize;
  int *table = parser->table;
  unsigned char doBonds = 0;

  // Initialize hash table used later when reading the special bonds
  // This is necessary because PDBx files don't provide atom numbers
  // for the special bonds and instead just give atom type/chain/resid
  // It provides a mapping from the resid+chain -> linked list of all atoms
  // that have that resid and chain
  inthash_init(&parser->bondHash, parser->natoms);

  for (i = 0; i < tableSize; i++)
  {
    switch (table[i])
    {     
    case COLUMN_ATOM_TYPE:
      columns[i]= atomtypebuffer;
      break;

    case COLUMN_NUMBER:
      columns[i] = trash;
      break;

    case COLUMN_NAME:
      columns[i] = namebuffer;
      break;

    case COLUMN_TYPE:
      columns[i] = atoms->type;
      typeIdx = i;
      break;

    case COLUMN_TYPE_AUTH:
      columns[i] = typeAuth;
      typeAuthIdx = i;
      break;

    case COLUMN_RESNAME:
      columns[i] = atoms->resname;
      resnameIdx = i;
      break;

    case COLUMN_RESID:
      columns[i] = residbuffer;
      break;

    case COLUMN_RESID_AUTH:
      columns[i] = residAuthbuffer;
      doBonds++;
      break;

    case COLUMN_INSERTION:
      columns[i] = atoms->insertion;
      insertionIdx = i;
      parseFlags |= FLAG_INSERTION;
      break;

    case COLUMN_X:
      columns[i] = xbuffer;
      break;

    case COLUMN_Y:
      columns[i] = ybuffer;
      break;

    case COLUMN_Z:
      columns[i] = zbuffer;
      break;

    case COLUMN_OCCUPANCY:
      columns[i] = occupancybuffer;
      break;

    case COLUMN_BFACTOR:
      columns[i] = bfactorbuffer;
      break;

    case COLUMN_CHARGE:
      columns[i] = chargebuffer;
      break;

    case COLUMN_CHAIN:
#if (vmdplugin_ABIVERSION < 20)
      columns[i] = chainbuffer;
#else
      columns[i] = atoms->chain;
      chainIdx = i;
#endif
      break;

    case COLUMN_CHAIN_AUTH:
      columns[i] = chainAuth;
      chainAuthIdx = i;
      doBonds++;
      break;

    case COLUMN_MODEL_NUM:
      columns[i] = model_num_buf;
      parseFlags |= FLAG_MODEL_NUM;
      break;

    default:
      columns[i] = trash;
      break;
    }
  }

  // If the two optional auth fields aren't present, don't look for extra bonds
  if (doBonds != MAX_OPTIONAL_AUTH_FIELDS)
  {
    doBonds = 0;
  }

  // Start parsing, Skip through junk
  atomdata = 0;
  while (!atomdata)
  {
    if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
    {
      printf("pdbxplugin) failure while reading file.\n");
      parser->error = true;
      return -1;
    }

    if (isStructureDataHeader(buffer))
    {
      atomdata = 1;
    }
  }

  // Skip through the atomdata table declaration
  while (atomdata)
  {
    if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
    {
      printf("pdbxplugin) failure while reading file\n");
      parser->error = true;
      return -1;
    }

    if (!isStructureDataHeader(buffer))
    {
      atomdata = 0;
    }
  }

  count = 0;
  atom = atoms;
  do
  {
    if (count >= parser->natoms)
    {
      printf("pdbxplugin) ERROR: number of atoms is larger than predicted. Exiting...\n");
      return -1;
    }

    pos = 0;
    for (i = 0; i < tableSize; ++i)
    {
      if (table[i] == COLUMN_JUNK)
      {
        // if we don't want this column, update pos to point to the next column     
        skipNextWord(buffer, buffer, pos, sizeof(buffer));
      }
      else
      {
        // will copy each column string into the atom struct
        // or save the string if we need to convert it
        getNextWord(buffer, columns[i], pos, sizeof(buffer), COLUMN_BUFFER_SIZE);
      }

    }

    strcpy(atom->atom_type, atomtypebuffer);

    // Coordinates must be saved until timestep is called
    xyzcount = count * 3;

    // replacing atof with stringToFloat will increase performance
    parser->xyz[xyzcount] = atof(xbuffer);
    parser->xyz[xyzcount + 1] = atof(ybuffer);
    parser->xyz[xyzcount + 2] = atof(zbuffer);

    atom->resid = atoi(residbuffer);
    if (doBonds && residAuthbuffer[0] != '.' && residAuthbuffer[0] != '?')
    {
      parser->resid_auth[count] = atoi(residAuthbuffer);

      // add atom to hash table
      // This attempts to generate a "unique id" based off the chain and resid
      hashTemp = getUniqueResID(chainAuth, parser->resid_auth[count]);

      if (-1 != (head = inthash_insert(&parser->bondHash, hashTemp, hashCount)))
      {
        // key already exists, so we have to "add" a node to the linked list
        // for this residue.  Since we can't change the pointer in the
        // hash table, we insert the node at the second position in the list
        parser->hashMem[hashCount].next = parser->hashMem[head].next;
        parser->hashMem[head].next = hashCount;
      }

      // "add" node to list
      parser->hashMem[hashCount++].index = count;
    }

    // XXX replace '?' or '.' insertion codes with a NUL char
    // indicating an empty insertion code.
    if (insertionIdx == MAX_COLUMNS - 1 || atom->insertion[0] == '?' || atom->insertion[0] == '.')
    {
      atom->insertion[0] = '\0';
      if (parseFlags & FLAG_INSERTION)
      {
        parseFlags ^= FLAG_INSERTION;
      }
    }

// TODO: figure out what this conditional should be
#if (vmdplugin_ABIVERSION < 20)
    /* check to see if the chain length is greater than 2 */
    if (chainbuffer[2] != '\0' && chainbuffer[1] != '\0')
    {
      chainbuffer[2] = '\0';
      parseFlags |= FLAG_CHAIN_LENGTH;
    }
    atom->chain[0] = chainbuffer[0];
    atom->chain[1] = chainbuffer[1];
#endif

    // Assign these to the pdbx_data struct
    if (bfactorbuffer[0] != '.' && bfactorbuffer[0] != '.')
    {
      atom->bfactor = atof(bfactorbuffer);
      ++bfactorcount;
      parseFlags |= FLAG_BFACTOR;
    }
    else
    {
      atom->bfactor = 0.0;
    }

    if (occupancybuffer[0] != '.' && occupancybuffer[0] != '?')
    {
      atom->occupancy = atof(occupancybuffer);
      ++occupancycount;
      parseFlags |= FLAG_OCCUPANCY;
    }
    else
    {
      atom->occupancy = 0.0;
    }

    if (chargebuffer[0] != '.' && chargebuffer[0] != '?')
    {
      atom->charge = atof(chargebuffer);
      ++chargecount;
      parseFlags |= FLAG_CHARGE;
    }
    else
    {
      atom->charge = 0.0;
    }

    idx = get_pte_idx_from_string(namebuffer);

    // check for parenthesis in atom type
    if (atom->type[0] == '"')
    {
      // only save what is inside the parenthesis
      i = 1;
      while (atom->type[i] != '"')
      {
        atom->type[i - 1] = atom->type[i];
        ++i;
      }
      atom->type[i - 1] = '\0';
    }

    if ((!vmdatomnamefrompdbxname) ||
        (strlen(namebuffer) == 0 || strlen(namebuffer) > 3))
    {
      // atom->name and atom-> are the same
      strcpy(atom->name, atom->type);
    }
    else
    {
      strcpy(atom->name, namebuffer);
    }

    // Set periodic table values
    if (idx != 0)
    {
      atom->atomicnumber = idx;
      atom->mass = get_pte_mass(idx);
      atom->radius = get_pte_vdw_radius(idx);
    }
    else
    {
      ++badptecount;
    }

    if (parseFlags & FLAG_MODEL_NUM)
    {
      if (model_num_buf[0] != '\0')
      {
        atom->altloc[0] = model_num_buf[0];
      }
      if (model_num_buf[1] != '\0')
      {
        atom->altloc[1] = model_num_buf[1];
      }
    }

    if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
    {
      printf("pdbxplugin) failure while reading file\n");
      parser->error = true;
      return -1;
    }

    ++count;
    ++atom;
    typeAuth += TYPE_SIZE;
    if (doBonds)
    {
      chainAuth += CHAIN_SIZE;
      columns[chainAuthIdx] = chainAuth;
    }
    columns[typeAuthIdx] = typeAuth;
    columns[typeIdx] = atom->type;
    columns[resnameIdx] = atom->resname;
    columns[insertionIdx] = atom->insertion;
#if (vmdplugin_ABIVERSION >= 20)
    columns[chainIdx] = atom->chain;
#endif
  } while (buffer[0] != '#'); //do until all the atoms have been read

  // after we finish parsing, set optflags
#if (vmdplugin_ABIVERSION < 20)
  if (parseFlags & FLAG_CHAIN_LENGTH)
  {
    printf("pdbxplugin) WARNING: This plugin ABI does not support chain names longer than two characters. Some chain names have been truncated.\n");
  }
#endif

  if (badptecount == 0)
  {
    *optflags |= MOLFILE_MASS | MOLFILE_RADIUS | MOLFILE_ATOMICNUMBER;
  }

  if (parseFlags & FLAG_INSERTION)
  {
    *optflags |= MOLFILE_INSERTION;
  }

  if (parseFlags & FLAG_CHARGE)
  {
    *optflags |= MOLFILE_CHARGE;
  }

  if (parseFlags & FLAG_BFACTOR)
  {
    *optflags |= MOLFILE_BFACTOR;
  }

  if (parseFlags & FLAG_OCCUPANCY)
  {
    *optflags |= MOLFILE_OCCUPANCY;
  }

  if (parseFlags & FLAG_MODEL_NUM)
  {
    *optflags |= MOLFILE_ALTLOC;
  }

  if (badptecount > 0)
  {
    printf("pdbxplugin) encountered %d bad element indices!\n", badptecount);
    return -1;
  }

  return 0;
}

#define BOND_JUNK 0
#define BOND_NAME_1 1
#define BOND_CHAIN_1 2
#define BOND_RESNAME_1 3
#define BOND_RESID_1 4
#define BOND_NAME_2 5
#define BOND_CHAIN_2 6
#define BOND_RESNAME_2 7
#define BOND_RESID_2 8

static bool readAngleBonds(molfile_atom_t *atoms, pdbxParser *parser)
{
  char buffer[BUFFER_SIZE];
  char *columns[MAX_COLUMNS];
  int bondTableSize = 0;
  int bnum = 0;
  int i, pos, k;
  int *newBondsTo, *newBondsFrom;
  fpos_t filePos;
  char junk[COLUMN_BUFFER_SIZE];
  char name1[COLUMN_BUFFER_SIZE];
  char name2[COLUMN_BUFFER_SIZE];
  char chain1[COLUMN_BUFFER_SIZE];
  char chain2[COLUMN_BUFFER_SIZE];
  char resid1buffer[COLUMN_BUFFER_SIZE];
  char resid2buffer[COLUMN_BUFFER_SIZE];
  int resid1, resid2;
  int uid1, uid2;
  int aIdx1, aIdx2;
  int n_angle_bonds = 0;

  rewind(parser->file);

  // skip through the file until we find the angle/bond information
  do
  {
    if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
    {
      return false;
    }
  } while (NULL == strstr(buffer, "_pdbx_validate_rmsd_angle."));

  fgetpos(parser->file, &filePos);

  // Parse table header data
  while (NULL != strstr(buffer, "_pdbx_validate_rmsd_angle."))
  {
    // assign integer values to each column
    if (NULL != strstr(buffer + 26, "auth_atom_id_1"))
    {
      columns[bondTableSize] = (char *)name1;
    }
    else if (NULL != strstr(buffer + 26, "auth_asym_id_1"))
    {
      columns[bondTableSize] = (char *)chain1;
    }
    else if (NULL != strstr(buffer + 26, "auth_seq_id_1"))
    {
      columns[bondTableSize] = (char *)resid1buffer;
    }
    else if (NULL != strstr(buffer + 26, "auth_atom_id_2"))
    {
      columns[bondTableSize] = (char *)name2;
    }
    else if (NULL != strstr(buffer + 26, "auth_asym_id_2"))
    {
      columns[bondTableSize] = (char *)chain2;
    }
    else if (NULL != strstr(buffer + 26, "auth_seq_id_2"))
    {
      columns[bondTableSize] = (char *)resid2buffer;
    }
    else
    {
      columns[bondTableSize] = (char *)junk;
    }
    ++bondTableSize;

    if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
    {
      printf("pdbxplugin) could not read bond information.\n");
      return false;
    }
  }

  // figure out how many bonds are being defined
  while (buffer[0] != '#')
  {
    if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
    {
      printf("pdbxplugin) could not read bond information.\n");
      return false;
    }
    ++bnum;
  }

  n_angle_bonds = bnum;
  if ((newBondsTo = (int *)realloc((void *)parser->bondsTo,
                                   (parser->nbonds + bnum) * sizeof(int))) == NULL)
  {
    printf("pdbxplugin) ERROR: could not reallocate bonds array.\n");
    return false;
  }
  if ((newBondsFrom = (int *)realloc((void *)parser->bondsFrom,
                                     (parser->nbonds + bnum) * sizeof(int))) == NULL)
  {
    printf("pdbxplugin) ERROR: could not reallocate bonds array.\n");
    return false;
  }
  parser->bondsTo = newBondsTo;
  parser->bondsFrom = newBondsFrom;

  // Skip back to the start of the bond info
  fsetpos(parser->file, &filePos);
  if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
  {
    printf("pdbxplugin) could not read bond information.\n");
    return false;
  }

  // Skip through the header
  while (NULL != strstr(buffer, "_pdbx_validate_rmsd_angle."))
  {
    if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
    {
      printf("pdbxplugin) could not read bond information.\n");
      return false;
    }
  }

  bnum = 0;
  while (buffer[0] != '#')
  {
    pos = 0;
    // copy each column of the table into the appropriate columns index
    for (i = 0; i < bondTableSize; ++i)
    {
      getNextWord(buffer, columns[i], pos, sizeof(buffer), COLUMN_BUFFER_SIZE);
    }
    resid1 = atoi(resid1buffer);
    resid2 = atoi(resid2buffer);

    // get unique res ID for hash table lookup
    uid1 = getUniqueResID(chain1, resid1);
    uid2 = getUniqueResID(chain2, resid2);
    k = 0;

    // find the atoms in the hash table
    if (((uid1 = inthash_lookup(&parser->bondHash, uid1)) != -1) && ((uid2 = inthash_lookup(&parser->bondHash, uid2)) != -1))
    {
      // because the hashtable is residue specifc, loop through
      // all atoms in the residue to find the correct one
      // Find atom 1
      do
      {
        aIdx1 = parser->hashMem[uid1].index;
        if (strcmp(name1, parser->type_auth + aIdx1 * TYPE_SIZE) == 0 &&
            parser->resid_auth[aIdx1] == resid1 &&
            strcmp(chain1, parser->chain_auth + aIdx1 * CHAIN_SIZE) == 0)
        {
          k++;
          break;
        }
        else
        {
          uid1 = parser->hashMem[uid1].next;
        }
      } while (uid1 != 0); //0 indicates end of "list"

      // Find atom 2
      do
      {
        aIdx2 = parser->hashMem[uid2].index;
        if (strcmp(name2, parser->type_auth + aIdx2 * TYPE_SIZE) == 0 &&
            parser->resid_auth[aIdx2] == resid2 &&
            strcmp(chain2, parser->chain_auth + aIdx2 * CHAIN_SIZE) == 0)
        {
          k++;
          break;
        }
        else
        {
          uid2 = parser->hashMem[uid2].next;
        }
      } while (uid2 != 0); // 0 indicates end of "list"

      if (k == 2)
      {
        // vmd doesn't use 0 based index for bond info?
        parser->bondsFrom[parser->nbonds + bnum] = aIdx1 + 1;
        parser->bondsTo[parser->nbonds + bnum] = aIdx2 + 1;
        ++bnum;
      }
    }
#ifdef PDBX_DEBUG
    else
    {
      printf("pdbxplugin) WARNING: Could not locate bond in hash table. %s %d\n", chain1, resid1);
      // This could occur if the number of chains/resids is large,
      // which could cause collisions in the bonds hash table.
      // Due to structore of pdbx special bonds, I'm not sure how we can get around this.
      if (uid1 == 0)
        printf("1 ");
      if (uid2 == 0)
        printf("2");
      printf("\n");
    }
#endif

    if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
    {
      printf("pdbxplugin) could not read RMSD bond deviation information.\n");
      return false;
    }
  }

  if (bnum != n_angle_bonds)
  {
    printf("pdbxplugin) ERROR: number of angle bonds does not match number of predicted bonds.\n");
  }
  parser->nbonds += bnum;

#ifdef PDBX_DEBUG
  printf("pdbxplugin) nbonds defined: %d\n", parser->nbonds);
#endif
  return bnum > 0;
}

static bool readRMSDBonds(molfile_atom_t *atoms, pdbxParser *parser)
{
  char buffer[BUFFER_SIZE];
  char *columns[64];
  int bondTableSize = 0;
  int bnum = 0;
  int i, k;
  fpos_t filePos;
  char junk[COLUMN_BUFFER_SIZE];
  char name1[COLUMN_BUFFER_SIZE];
  char name2[COLUMN_BUFFER_SIZE];
  char chain1[COLUMN_BUFFER_SIZE];
  char chain2[COLUMN_BUFFER_SIZE];
  char resid1buffer[COLUMN_BUFFER_SIZE];
  char resid2buffer[COLUMN_BUFFER_SIZE];
  int resid1, resid2;
  int uid1, uid2;
  int aIdx1, aIdx2;

  // skip through the file until we find the RMSD/bond information
  do
  {
    if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
    {
      parser->nbonds = 0;
      return false;
    }
  } while (!isValidateRMSDBond(buffer));

  fgetpos(parser->file, &filePos);

  // if (sscanf(  return if two words in one table definition line

  // Parse table header data
  while (isValidateRMSDBond(buffer))
  {
    // assign integer values to each column
    // 25 is length validateRMSDbond header name
    if (NULL != strstr(buffer + 25, "auth_atom_id_1"))
    {
      columns[bondTableSize] = (char *)name1;
    }
    else if (NULL != strstr(buffer + 25, "auth_asym_id_1"))
    {
      columns[bondTableSize] = (char *)chain1;
    }
    else if (NULL != strstr(buffer + 25, "auth_seq_id_1"))
    {
      columns[bondTableSize] = (char *)resid1buffer;
    }
    else if (NULL != strstr(buffer + 25, "auth_atom_id_2"))
    {
      columns[bondTableSize] = (char *)name2;
    }
    else if (NULL != strstr(buffer + 25, "auth_asym_id_2"))
    {
      columns[bondTableSize] = (char *)chain2;
    }
    else if (NULL != strstr(buffer + 25, "auth_seq_id_2"))
    {
      columns[bondTableSize] = (char *)resid2buffer;
    }
    else
    {
      columns[bondTableSize] = (char *)junk;
    }
    ++bondTableSize;

    if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
    {
      printf("pdbxplugin) could not read bond information.\n");
      return false;
    }
  }

  // figure out how many bonds are being defined
  while (buffer[0] != '#')
  {
    if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
    {
      printf("pdbxplugin) could not read bond information.\n");
      return false;
    }
    ++bnum;
  }

  parser->nbonds = bnum;
  parser->bondsTo = (int *)malloc(bnum * sizeof(int));
  parser->bondsFrom = (int *)malloc(bnum * sizeof(int));

  // Skip back to the start of the bond info
  fsetpos(parser->file, &filePos);
  if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
  {
    printf("pdbxplugin) could not read bond information.\n");
    return false;
  }

  // Skip through the header
  while (isValidateRMSDBond(buffer))
  {
    if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
    {
      printf("pdbxplugin) could not read bond information.\n");
      return false;
    }
  }

  bnum = 0;
  while (buffer[0] != '#')
  {
    int pos = 0;
    // copy each column of the table into the appropriate columns index
    for (i = 0; i < bondTableSize; ++i)
    {
      getNextWord(buffer, columns[i], pos, sizeof(buffer), COLUMN_BUFFER_SIZE);
    }
    resid1 = atoi(resid1buffer);
    resid2 = atoi(resid2buffer);

    // get unique res ID for hash table lookup
    uid1 = getUniqueResID(chain1, resid1);
    uid2 = getUniqueResID(chain2, resid2);
    k = 0;

    // Find the atoms in the hash table.
    // Because the hashtable is residue specifc, loop through all
    // atoms in the residue to find the correct one
    if (((uid1 = inthash_lookup(&parser->bondHash, uid1)) != -1) && ((uid2 = inthash_lookup(&parser->bondHash, uid2)) != -1))
    {
      // Find atom 1
      do
      {
        aIdx1 = parser->hashMem[uid1].index;
        if (strcmp(name1, parser->type_auth + aIdx1 * TYPE_SIZE) == 0 && parser->resid_auth[aIdx1] == resid1 && strcmp(chain1, parser->chain_auth + aIdx1 * CHAIN_SIZE) == 0)
        {
          k++;
          break;
        }
        else
        {
          uid1 = parser->hashMem[uid1].next;
        }
      } while (uid1 != 0); // 0 indicates end of "list"

      // Find atom 2
      do
      {
        aIdx2 = parser->hashMem[uid2].index;
        if (strcmp(name2, parser->type_auth + aIdx2 * TYPE_SIZE) == 0 && parser->resid_auth[aIdx2] == resid2 && strcmp(chain2, parser->chain_auth + aIdx2 * CHAIN_SIZE) == 0)
        {
          k++;
          break;
        }
        else
        {
          uid2 = parser->hashMem[uid2].next;
        }
      } while (uid2 != 0); // 0 indicates end of "list"

      // If we found both atoms add them to the bonds list
      if (k == 2)
      {
        parser->bondsFrom[bnum] = aIdx1 + 1; // vmd doesn't use 0 based index for bond info?
        parser->bondsTo[bnum] = aIdx2 + 1;
        ++bnum;
      }
    }
#ifdef PDBX_DEBUG
    else
    {
      printf("^^^^Could locate bond^^^^^, %s %d\n", chain1, resid1);
      printf("Error finding atom ");
      if (uid1 == 0)
        printf("1 ");
      if (uid2 == 0)
        printf("2");
      printf("\n");
    }
#endif

    if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
    {
      printf("pdbxplugin) could not read RMSD bond deviation information.\n");
      return false;
    }
  }

  if (parser->nbonds != bnum)
  {
    printf("pdbxplugin: ERROR: mismatch in number of bonds.\n");
  }

#ifdef PDBX_DEBUG
  printf("pdbxplugin) nbonds defined: %d\n", parser->nbonds);
#endif

  return (bnum > 0);
}

//
// Experimental support for Integrative Hybrid Modeling (IHM) structure data
// in enhanced PDBx files:
//   https://github.com/ihmwg/IHM-dictionary/blob/master/dictionary_documentation/documentation.md
//   https://pdb-dev.wwpdb.org/
//   https://python-ihm.readthedocs.io/en/latest/introduction.html
//
// At present the PDBx plugin makes an attempt to parse the
// following IHM record types:
//   _ihm_sphere_obj_site
//
static bool parse_pdbx_ihm_sphere_data(pdbxParser *parser)
{
  char buffer[BUFFER_SIZE];
  char *columns[32];
  char xbuffer[COLUMN_BUFFER_SIZE];
  char ybuffer[COLUMN_BUFFER_SIZE];
  char zbuffer[COLUMN_BUFFER_SIZE];
  char radbuffer[COLUMN_BUFFER_SIZE];
  int catlen = 0;
  int tableSize = 0;
  int nelems = 0;
  int i;
  fpos_t filePos;
  char junk[32];

  rewind(parser->file);

  // skip through the file until we find IHM sphere information
  do
  {
    if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
    {
      parser->nbonds = 0;
      return false;
    }
  } while (NULL == strstr(buffer, "_ihm_sphere_obj_site."));

  // record location of the start of IHM sphere info
  fgetpos(parser->file, &filePos);

  // Parse table header data
  catlen = strlen("_ihm_sphere_obj_site.");
  tableSize = 0;
  while (NULL != strstr(buffer, "_ihm_sphere_obj_site."))
  {
    // assign data fields to columns
    const char *fieldbuf = buffer + catlen;

    if (NULL != strstr(fieldbuf, "object_radius"))
    {
      columns[tableSize] = (char *)radbuffer;
    }
    else if (NULL != strstr(fieldbuf, "Cartn_x"))
    {
      columns[tableSize] = (char *)xbuffer;
    }
    else if (NULL != strstr(fieldbuf, "Cartn_y"))
    {
      columns[tableSize] = (char *)ybuffer;
    }
    else if (NULL != strstr(fieldbuf, "Cartn_z"))
    {
      columns[tableSize] = (char *)zbuffer;
    }
    else
    {
      columns[tableSize] = (char *)junk;
    }
    ++tableSize;

    if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
    {
      printf("pdbxplugin) could not read IHM '_ihm_sphere_obj_site' information.\n");
      return false;
    }
  }

  // figure out how many elems are being defined
  nelems = 0;
  while (buffer[0] != '#')
  {
    ++nelems;
    if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
    {
      break;
    }
  }

  // Skip back to the start of the IHM sphere info
  fsetpos(parser->file, &filePos);
  if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
  {
    printf("pdbxplugin) could not read IHM '_ihm_sphere_obj_site' information.\n");
    return false;
  }

  // Skip through the header
  while (NULL != strstr(buffer, "_ihm_sphere_obj_site."))
  {
    if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
    {
      printf("pdbxplugin) could not read IHM '_ihm_sphere_obj_site' information.\n");
      return false;
    }
  }

  // allocate graphics buffer sized to sphere count
  parser->n_graphics_elems = nelems;
  parser->g_data = new molfile_graphics_t[nelems];

  nelems = 0; // reset counter so we can use it again
  while (buffer[0] != '#')
  {
    int pos = 0;
    // copy each column of the table into the appropriate columns index
    for (i = 0; i < tableSize; ++i)
    {
      getNextWord(buffer, columns[i], pos, sizeof(buffer), COLUMN_BUFFER_SIZE);
    }
    parser->g_data[nelems].type = MOLFILE_SPHERE;
    parser->g_data[nelems].style = 12;
    parser->g_data[nelems].size = atof(radbuffer);
    parser->g_data[nelems].data[0] = atof(xbuffer);
    parser->g_data[nelems].data[1] = atof(ybuffer);
    parser->g_data[nelems].data[2] = atof(zbuffer);

    nelems++;
    if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
    {
      break;
    }
  }

  return nelems > 0;
}

static bool parse_pdbx_ihm_restraints_data(pdbxParser *parser)
{
  char buffer[BUFFER_SIZE];
  char *columns[32];
  char groupbuffer[COLUMN_BUFFER_SIZE];
  char entity_description_1[COLUMN_BUFFER_SIZE];
  char entity_id_1[COLUMN_BUFFER_SIZE];
  char seq_id_1[COLUMN_BUFFER_SIZE];
  char comp_id_1[COLUMN_BUFFER_SIZE];
  char entity_description_2[COLUMN_BUFFER_SIZE];
  char entity_id_2[COLUMN_BUFFER_SIZE];
  char seq_id_2[COLUMN_BUFFER_SIZE];
  char comp_id_2[COLUMN_BUFFER_SIZE];
  char crosslink_type[COLUMN_BUFFER_SIZE];
  char asym_id_1[COLUMN_BUFFER_SIZE];
  char asym_id_2[COLUMN_BUFFER_SIZE];
  int catlen = 0;
  int tableSize = 0;
  int nelems = 0;
  int i;
  fpos_t crosslinkPos, crosslinkrestraintPos;
  char junk[32];

  int verbose = (getenv("VMDPDBXVERBOSE") != NULL);

  //
  // parse crosslink records
  //
  rewind(parser->file);

  // skip through the file until we find IHM cross link information
  do
  {
    if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
    {
      parser->nbonds = 0;
      return false;
    }
  } while (NULL == strstr(buffer, "_ihm_cross_link_list."));

  // record location of the start of IHM sphere info
  fgetpos(parser->file, &crosslinkPos);

  // Parse table header data
  catlen = strlen("_ihm_cross_link_list.");
  tableSize = 0;
  memset(columns, 0, sizeof(columns));
  while (NULL != strstr(buffer, "_ihm_cross_link_list."))
  {
    // assign data fields to columns
    const char *fieldbuf = buffer + catlen;
    if (NULL != strstr(fieldbuf, "group_id"))
    {
      columns[tableSize] = (char *)groupbuffer;
    }
    else if (NULL != strstr(fieldbuf, "entity_description_1"))
    {
      columns[tableSize] = (char *)entity_description_1;
    }
    else if (NULL != strstr(fieldbuf, "entity_id_1"))
    {
      columns[tableSize] = (char *)entity_id_1;
    }
    else if (NULL != strstr(fieldbuf, "seq_id_1"))
    {
      columns[tableSize] = (char *)seq_id_1;
    }
    else if (NULL != strstr(fieldbuf, "comp_id_1"))
    {
      columns[tableSize] = (char *)comp_id_1;
    }
    else if (NULL != strstr(fieldbuf, "entity_description_2"))
    {
      columns[tableSize] = (char *)entity_description_2;
    }
    else if (NULL != strstr(fieldbuf, "entity_id_2"))
    {
      columns[tableSize] = (char *)entity_id_2;
    }
    else if (NULL != strstr(fieldbuf, "seq_id_2"))
    {
      columns[tableSize] = (char *)seq_id_2;
    }
    else if (NULL != strstr(fieldbuf, "comp_id_2"))
    {
      columns[tableSize] = (char *)comp_id_2;
    }
    else if (NULL != strstr(fieldbuf, "type"))
    {
      columns[tableSize] = (char *)crosslink_type;
    }
    else
    {
      columns[tableSize] = (char *)junk;
    }
    ++tableSize;

    if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
    {
      printf("pdbxplugin) could not read IHM '_ihm_cross_link_list' information.\n");
      return false;
    }
  }

  // figure out how many elems are being defined
  nelems = 0;
  while (buffer[0] != '#')
  {
    ++nelems;
    if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
    {
      break;
    }
  }

  // Skip back to the start of the IHM crosslink info
  fsetpos(parser->file, &crosslinkPos);
  if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
  {
    printf("pdbxplugin) could not read IHM '_ihm_cross_link_list' information.\n");
    return false;
  }

  // Skip through the header
  while (NULL != strstr(buffer, "_ihm_cross_link_list."))
  {
    if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
    {
      printf("pdbxplugin) could not read IHM '_ihm_cross_link_list' information.\n");
      return false;
    }
  }

  // XXX use nelems to allocate storage for output

  if (nelems > 0)
  {
    printf("Found %d IHM crosslinks:\n", nelems);
    nelems = 0; // reset counter so we can use it again
    while (buffer[0] != '#')
    {
      int pos = 0;
      // copy each column of the table into the appropriate columns index
      for (i = 0; i < tableSize; ++i)
      {
        getNextWord(buffer, columns[i], pos, sizeof(buffer), COLUMN_BUFFER_SIZE);
      }

      if (verbose)
      {
        printf("[%d] %s, 1:%s %s %s %s, 2:%s %s %s %s, %s\n",
               nelems, groupbuffer,
               entity_description_1, entity_id_1, seq_id_1, comp_id_1,
               entity_description_2, entity_id_2, seq_id_2, comp_id_2,
               crosslink_type);
      }

      nelems++;

      if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
      {
        break;
      }
    }
  }

  //
  // parse crosslink restraints
  //

  // If we don't have any crosslink records, there's no value
  // to trying to parse restraint records that depend on them
  if (nelems < 1)
  {
    rewind(parser->file);
    return 0;
  }

  // skip through the file until we find IHM cross link information
  do
  {
    if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
    {
      parser->nbonds = 0;
      return false;
    }
  } while (NULL == strstr(buffer, "_ihm_cross_link_restraint."));

  // record location of the start of IHM sphere info
  fgetpos(parser->file, &crosslinkrestraintPos);

  // Parse table header data
  tableSize = 0;
  memset(columns, 0, sizeof(columns));
  catlen = strlen("_ihm_cross_link_restraint.");
  while (NULL != strstr(buffer, "_ihm_cross_link_restraint."))
  {
    // assign data fields to columns
    const char *fieldbuf = buffer + catlen;
    if (NULL != strstr(fieldbuf, "group_id"))
    {
      columns[tableSize] = (char *)groupbuffer;
    }
    else if (NULL != strstr(fieldbuf, "entity_id_1"))
    {
      columns[tableSize] = (char *)entity_id_1;
    }
    else if (NULL != strstr(fieldbuf, "asym_id_1"))
    {
      columns[tableSize] = (char *)asym_id_1;
    }
    else if (NULL != strstr(fieldbuf, "seq_id_1"))
    {
      columns[tableSize] = (char *)seq_id_1;
    }
    else if (NULL != strstr(fieldbuf, "comp_id_1"))
    {
      columns[tableSize] = (char *)comp_id_1;
    }
    else if (NULL != strstr(fieldbuf, "entity_id_2"))
    {
      columns[tableSize] = (char *)entity_id_2;
    }
    else if (NULL != strstr(fieldbuf, "asym_id_2"))
    {
      columns[tableSize] = (char *)asym_id_2;
    }
    else if (NULL != strstr(fieldbuf, "seq_id_2"))
    {
      columns[tableSize] = (char *)seq_id_2;
    }
    else if (NULL != strstr(fieldbuf, "comp_id_2"))
    {
      columns[tableSize] = (char *)comp_id_2;
    }
    else if (NULL != strstr(fieldbuf, "type"))
    {
      columns[tableSize] = (char *)crosslink_type;
    }
    else
    {
      columns[tableSize] = (char *)junk;
    }
    ++tableSize;

    if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
    {
      printf("pdbxplugin) could not read IHM '_ihm_cross_link_restraint' information.\n");
      return false;
    }
  }

  // figure out how many elems are being defined
  nelems = 0;
  while (buffer[0] != '#')
  {
    ++nelems;
    if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
    {
      break;
    }
  }

  // Skip back to the start of the IHM crosslink info
  fsetpos(parser->file, &crosslinkrestraintPos);
  if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
  {
    printf("pdbxplugin) could not read IHM '_ihm_cross_link_restraint' information.\n");
    return false;
  }

  // Skip through the header
  while (NULL != strstr(buffer, "_ihm_cross_link_restraint."))
  {
    if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
    {
      printf("pdbxplugin) could not read IHM '_ihm_cross_link_restraint' information.\n");
      return false;
    }
  }

  // XXX use nelems to allocate storage for output

  if (nelems > 0)
  {
    printf("Found %d IHM crosslink restraints:\n", nelems);

    nelems = 0; // reset counter so we can use it again
    while (buffer[0] != '#')
    {
      int pos = 0;
      // copy each column of the table into the appropriate columns index
      for (i = 0; i < tableSize; ++i)
      {
        getNextWord(buffer, columns[i], pos, sizeof(buffer), COLUMN_BUFFER_SIZE);
      }

      if (verbose)
      {
        printf("[%d] %s, 1:%s %s %s %s, 2:%s %s %s %s, %s\n",
               nelems, groupbuffer,
               entity_id_1, asym_id_1, seq_id_1, comp_id_1,
               entity_id_2, asym_id_2, seq_id_2, comp_id_2,
               crosslink_type);
      }

      nelems++;

      if (NULL == fgets(buffer, BUFFER_SIZE, parser->file))
      {
        break;
      }
    }
  }

  return nelems > 0;
}

// Parse any graphics objects that are not otherwise associated
// with atomic structure fields in the molfile plugin API.
static bool parse_pdbx_graphics_data(pdbxParser *parser)
{
  bool rc = false;
  // XXX Integrated Hybrid Modeling (IHM) structure information
  //      are presently represented only as VMD graphics objects,
  //      until we add the necessary APIs and user interfaces to
  //      make direct use of the data for other purposes.
  rc = parse_pdbx_ihm_sphere_data(parser);
  if (!rc)
    printf("pdbxplugin) No IHM sphere graphics objects defined.\n");

#if 0
  rc = parse_pdbx_ihm_restraints_data(parser);
  if (!rc)
    printf("pdbxplugin) No IHM crosslinks found.\n");
#endif

  return rc;
}

static bool readBonds(molfile_atom_t *atoms, pdbxParser *parser)
{
  bool retval = readRMSDBonds(atoms, parser);
  retval = readAngleBonds(atoms, parser) || retval;
  return retval;
}

static inline bool isValidateRMSDBond(char *str)
{
  // return str[0-24] == "_pdbx_validate_rmsd_bond."
  return (str[0] == '_' && str[1] == 'p' && str[2] == 'd' && str[3] == 'b' &&
          str[4] == 'x' && str[5] == '_' && str[6] == 'v' && str[7] == 'a' &&
          str[8] == 'l' && str[9] == 'i' && str[10] == 'd' && str[11] == 'a' &&
          str[12] == 't' && str[13] == 'e' && str[14] == '_' && str[15] == 'r' &&
          str[16] == 'm' && str[17] == 's' && str[18] == 'd' && str[19] == '_' &&
          str[20] == 'b' && str[21] == 'o' && str[22] == 'n' && str[23] == 'd' &&
          str[24] == '.');
}

static inline bool isAtomSite(char *str)
{
  return (str[0] == '_' && str[1] == 'a' && str[2] == 't' && str[3] == 'o' && str[4] == 'm' &&
          str[5] == '_' && str[6] == 's' && str[7] == 'i' && str[8] == 't' && str[9] == 'e' &&
          str[10] == '.');
}

//
// start of pdbxWriter implementation
//
static pdbxWriter *create_pdbxWriter(const char *filename, int numAtoms)
{
  pdbxWriter *writer = new pdbxWriter;
  memset(writer, 0, sizeof(pdbxWriter));
  int length = strlen(filename);
  int start = 0;
  int end = length;
  int i;
  writer->numatoms = numAtoms;
  writer->bufferCount = 0;
  writer->fd = fopen(filename, "w");

  // get name of pdb file
  for (i = 0; i < length; ++i)
  {
    if (filename[i] == '/' || filename[i] == '\\')
    {
      if (i + 1 < length)
        start = i + 1;
    }

    if (filename[i] == '.')
      end = i;
  }

  strncpy(writer->pdbName, filename + start, end - start);
  writer->pdbName[end - start] = '\0';
  return writer;
}

static void addCoordinates(const float *coords, pdbxWriter *writer)
{
  writer->coordinates = coords;
}

static void addAtoms(const molfile_atom_t *atomlist, int optflags, pdbxWriter *writer)
{
  int i;
  writer->atoms = new molfile_atom_t[writer->numatoms];
  molfile_atom_t *atoms = writer->atoms;

  memcpy(atoms, atomlist, writer->numatoms * sizeof(molfile_atom_t));

  // If occ, bfactor, and insertion aren't given, we assign defaultvalues.
  if (!(optflags & MOLFILE_OCCUPANCY))
  {
    for (i = 0; i < writer->numatoms; i++)
      atoms[i].occupancy = 0.0f;
  }

  if (!(optflags & MOLFILE_BFACTOR))
  {
    for (i = 0; i < writer->numatoms; i++)
      atoms[i].bfactor = 0.0f;
  }

  if (!(optflags & MOLFILE_INSERTION))
  {
    for (i = 0; i < writer->numatoms; i++)
    {
      atoms[i].insertion[0] = ' ';
      atoms[i].insertion[1] = '\0';
    }
  }

  if (!(optflags & MOLFILE_ALTLOC))
  {
    for (i = 0; i < writer->numatoms; i++)
    {
      atoms[i].altloc[0] = ' ';
      atoms[i].altloc[1] = '\0';
    }
  }

  if (!(optflags & MOLFILE_ATOMICNUMBER))
  {
    for (i = 0; i < writer->numatoms; i++)
      atoms[i].atomicnumber = 0;
  }
}

static void writeAtomSite(pdbxWriter *writer)
{
  char lineBuffer[BUFFER_SIZE];
  int i;
  const float *x, *y, *z;
  molfile_atom_t *atoms = writer->atoms;
  memset(lineBuffer, 0, sizeof(lineBuffer));
  x = writer->coordinates;
  y = x + 1;
  z = x + 2;

  for (i = 0; i < writer->numatoms; ++i)
  {
    sprintf(lineBuffer, "ATOM %d %s %s . %s %s . %d ? %f %f %f %f %f %s\n",
            i + 1, atoms[i].name, atoms[i].type, atoms[i].resname, atoms[i].chain,
            atoms[i].resid, *x, *y, *z, atoms[i].occupancy,
            atoms[i].charge, atoms[i].chain);
    x += 3;
    y += 3;
    z += 3;
    write(lineBuffer, writer);
  }
}

static void writeFile(pdbxWriter *writer)
{
  // write PDBx header
  writeIntro(writer);
  write(atomSiteHeader, writer);
  writeAtomSite(writer);
  write("#\n", writer);
  close(writer);
}

static void writeIntro(pdbxWriter *writer)
{
  write("data_", writer);
  write(writer->pdbName, writer);
  write("\n", writer);
}

static void close(pdbxWriter *writer)
{
  writeBuffer(writer);
  fclose(writer->fd);
}

static void write(const char *str, pdbxWriter *writer)
{
  int length = strlen(str);
  int copy_size;
  int num_copied = 0;

  if (length + writer->bufferCount < WB_SIZE)
  {
    memcpy(writer->writeBuf + writer->bufferCount, str, length);
    writer->bufferCount += length;
  }
  else
    do
    {
      copy_size = WB_SIZE - writer->bufferCount;
      if (copy_size + num_copied > length)
      {
        copy_size = length - num_copied;
      }
      memcpy(writer->writeBuf + writer->bufferCount, str + num_copied, copy_size);
      writer->bufferCount += copy_size;
      num_copied += copy_size;
      if (writer->bufferCount == WB_SIZE)
      {
        writeBuffer(writer);
      }
    } while (num_copied < length);
}

static void writeBuffer(pdbxWriter *writer)
{
  if (writer->bufferCount == 0)
    return;
  fwrite(writer->writeBuf, sizeof(char), writer->bufferCount, writer->fd);
  writer->bufferCount = 0;
}

//
// API functions start here
//
typedef struct
{
  pdbxParser *parser;
  pdbxWriter *writer;
  int natoms;
  molfile_atom_t *atomlist;
  molfile_metadata_t *meta;
  int readTS;
} pdbx_data;

static void *open_pdbx_read(const char *filepath, const char *filetype,
                            int *natoms)
{
  pdbx_data *data;
  data = new pdbx_data;
  data->readTS = 0;
  data->parser = create_pdbxParser(filepath);
  data->natoms = data->parser->natoms;
  *natoms = data->natoms;
  if (data->parser->error)
  {
    printf("pdbxplugin) error opening file.\n");
    return NULL;
  }
  return data;
}

static int read_pdbx_structure(void *mydata, int *optflags, molfile_atom_t *atoms)
{
  pdbx_data *data = (pdbx_data *)mydata;
  *optflags = MOLFILE_NOOPTIONS;

  if (data->parser->natoms == 0)
  {
    printf("pdbxplugin) No atoms found.\n");
    if (data->parser->pdb_dev)
    {
      return MOLFILE_NOSTRUCTUREDATA;
    }
    return MOLFILE_ERROR;
  }

  if (parseStructure(atoms, optflags, data->parser))
  {
    printf("pdbxplugin) Error while trying to parse pdbx structure\n");
    return MOLFILE_ERROR;
  }

  if (readBonds(atoms, data->parser))
  {
    *optflags |= MOLFILE_BONDSSPECIAL;
  }
  return MOLFILE_SUCCESS;
}

static int read_bonds(void *v, int *nbonds, int **fromptr, int **toptr,
                      float **bondorder, int **bondtype,
                      int *nbondtypes, char ***bondtypename)
{
  pdbx_data *data = (pdbx_data *)v;
  if (data->parser->nbonds == 0)
  {
    *nbonds = 0;
    *fromptr = NULL;
    *toptr = NULL;
  }
  else
  {
    *nbonds = data->parser->nbonds;
    printf("pdbxplugin) Found %d 'special bonds' in the PDBx file.\n", *nbonds);
    *fromptr = data->parser->bondsFrom;
    *toptr = data->parser->bondsTo;
  }
  *bondorder = NULL;
  *bondtype = NULL;
  *nbondtypes = 0;
  *bondtypename = NULL;

  return MOLFILE_SUCCESS;
}

static int read_pdbx_timestep(void *mydata, int natoms, molfile_timestep_t *ts)
{
  pdbx_data *data = (pdbx_data *)mydata;
  if (data->readTS)
  {
    return MOLFILE_ERROR;
  }
  data->readTS = 1;
  memcpy(ts->coords, data->parser->xyz, natoms * 3 * sizeof(float));

  return MOLFILE_SUCCESS;
}

static int read_rawgraphics(void *v, int *nelem, const molfile_graphics_t **g_data)
{
  pdbx_data *data = (pdbx_data *)v;

  if (data->parser->pdb_dev && parse_pdbx_graphics_data(data->parser))
  {
    *nelem = data->parser->n_graphics_elems;
    *g_data = data->parser->g_data;
  }
  else
  {
    *nelem = 0;
    *g_data = NULL;
  }

  return MOLFILE_SUCCESS;
}

static void close_pdbx_read(void *v)
{
  pdbx_data *data = (pdbx_data *)v;
  delete_pdbxParser(data->parser);
  delete data;
}

static void *open_file_write(const char *path, const char *filetypye, int natoms)
{
  pdbx_data *data = new pdbx_data;
  data->writer = create_pdbxWriter(path, natoms);
  return data;
}

static int write_structure(void *v, int optflags, const molfile_atom_t *atoms)
{
  pdbx_data *data = (pdbx_data *)v;
  addAtoms(atoms, optflags, data->writer);
  return MOLFILE_SUCCESS;
}

static int write_timestep(void *v, const molfile_timestep_t *ts)
{
  pdbx_data *data = (pdbx_data *)v;
  addCoordinates(ts->coords, data->writer);
  writeFile(data->writer);
  return MOLFILE_SUCCESS;
}

static void close_file_write(void *v)
{
  pdbx_data *data = (pdbx_data *)v;
  delete[] data->writer->atoms;
  delete data->writer;
  delete data;
}

//
// Plugin initialization fctns and structures
//
static molfile_plugin_t plugin;

VMDPLUGIN_API int VMDPLUGIN_init()
{
  memset(&plugin, 0, sizeof(molfile_plugin_t));
  plugin.abiversion = vmdplugin_ABIVERSION;
  plugin.type = MOLFILE_PLUGIN_TYPE;
  plugin.name = "pdbx";
  plugin.prettyname = "mmCIF/PDBX";
  plugin.author = "Brendan McMorrow, John Stone";
  plugin.majorv = 0;
  plugin.minorv = 14;
  plugin.is_reentrant = VMDPLUGIN_THREADSAFE;
  plugin.filename_extension = "cif";
  plugin.open_file_read = open_pdbx_read;
  plugin.read_structure = read_pdbx_structure;
  plugin.read_next_timestep = read_pdbx_timestep;
  plugin.read_rawgraphics = read_rawgraphics;
  plugin.read_bonds = read_bonds;
  plugin.open_file_write = open_file_write;
  plugin.write_structure = write_structure;
  plugin.write_timestep = write_timestep;
  plugin.close_file_write = close_file_write;
  plugin.close_file_read = close_pdbx_read;
  return VMDPLUGIN_SUCCESS;
}

VMDPLUGIN_API int VMDPLUGIN_register(void *v, vmdplugin_register_cb cb)
{
  (*cb)(v, (vmdplugin_t *)&plugin);
  return VMDPLUGIN_SUCCESS;
}

VMDPLUGIN_API int VMDPLUGIN_fini()
{
  return VMDPLUGIN_SUCCESS;
}

#ifdef TEST_PLUGIN

int main(int argc, char *argv[])
{
  molfile_timestep_t timestep;
  pdbx_data *v;
  int natoms;
  int set;

  //  while (--argc) {

  struct timeval tot1, tot2;
  gettimeofday(&tot1, NULL);
  if (*argv != NULL)
  {
    v = (pdbx_data *)open_pdbx_read(argv[1], "pdbx", &natoms);
  }
  else
  {
    //   v = (pdbx_data*)open_pdbx_read("/Users/Brendan/pdbx/3j3q.cif", "pdbx", &natoms);
    v = (pdbx_data *)open_pdbx_read("/home/brendanbc1/Downloads/3j3q.cif", "pdbx", &natoms);
  }
  if (!v)
  {
    fprintf(stderr, "main) open_pdbx_read failed for file %s\n", argv[1]);
    return 1;
  }
#ifdef PDBX_DEBUG
  fprintf(stderr, "main) open_pdbx_read succeeded for file %s\n", argv[1]);
  fprintf(stderr, "main) number of atoms: %d\n", natoms);
#endif

  set = 0;
  molfile_atom_t *atoms = new molfile_atom_t[natoms];
  int rc = read_pdbx_structure(v, &set, atoms);
  if (rc != MOLFILE_ERROR)
  {
#ifdef PDBX_DEBUG
    printf("xyz structure successfully read.\n");
#endif
  }
  else
  {
    fprintf(stderr, "main) error reading pdbx file\n");
    return -1;
  }

  timestep.coords = new float[3 * natoms];
  if (!read_pdbx_timestep(v, natoms, &timestep))
  {
    fprintf(stderr, "main) open_pdbx_read succeeded for file %s\n", argv[1]);
  }
  else
  {
    fprintf(stderr, "main) Failed to read timestep\n");
  }
  int nbonds, nbondtypes;
  int *fromptr, *toptr, *bondtype;
  float *bondorder;
  char **bondtypename;
  read_bonds(v, &nbonds, &fromptr, &toptr,
             &bondorder, &bondtype,
             &nbondtypes, &bondtypename);

  const molfile_graphics_t *g_data;
  int n_graphics_elems;
  read_rawgraphics(v, &n_graphics_elems, &g_data);

  gettimeofday(&tot2, NULL);
  printf("Total time to read file: %f seconds\n",
         (double)(tot2.tv_usec - tot1.tv_usec) / 1000000 +
             (double)(tot2.tv_sec - tot1.tv_sec));
  close_pdbx_read(v);

  printf("\nWriting file...\n\n");
  v = (pdbx_data *)open_file_write("/tmp/test.cif", 0, natoms);

#ifdef PDBX_DEBUG
  printf("File opened for writing...\n");
#endif
  write_structure(v, set, (const molfile_atom_t *)atoms);
#ifdef PDBX_DEBUG
  printf("Structure information gathered...\n");
#endif
  write_timestep(v, &timestep);
#ifdef PDBX_DEBUG
  printf("File written...\n");
#endif
  close_file_write(v);
#ifdef PDBX_DEBUG
  printf("File closed.\n");
#endif
  delete[] atoms;
  delete[] timestep.coords;

#if 0
  printf("Writing pdbx.txt\n");
  x = timestep.coords; y = x+1;
  z = x+2;
  FILE *f;
  f = fopen("pdbx.txt", "w");
  for(i=0; i<natoms; i++) {
    fprintf(f, "%i %d %s %s %s %f %f %f\n", atoms[i].atomicnumber, atoms[i].resid, atoms[i].chain, atoms[i].resname, atoms[i].type, *x,*y,*z);
    //fprintf(stderr, "%i\t%s  %s\t%s  %s  %i  %f\t%f\t%f\t%f\t%f\t%f\n", i+1, atoms[i].name, atoms[i].type,
      //      atoms[i].chain, atoms[i].resname, atoms[i].resid, *x, *y, *z, atoms[i].occupancy, atoms[i].bfactor, atoms[i].charge);
    x+=3;
    y+=3;
    z+=3;
  }
  fclose(f);
  printf("main) pdbx.txt written\n");
#endif

  return 0;
}
#endif
