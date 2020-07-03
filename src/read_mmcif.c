#include "../headers/read_mmcif.h"

static molfile_plugin_t *api;

static int register_cb(void *v, vmdplugin_t *p)
{
    api = (molfile_plugin_t *)p;
    return 0;
}

void open_mmcif(const char *filepath, const char *filetype, int natoms)
{
    printf("opened read_mmcif\n");
    molfile_pdbxplugin_init();
    molfile_pdbxplugin_register(NULL, register_cb);
    printf("%s | %s |%d", filepath, filetype, natoms);
    printf("\n");
    void *h_in;
    molfile_timestep_t ts_in;
    molfile_qm_metadata_t metaqm_in;
    molfile_qm_timestep_t qm_ts_in;
    molfile_atom_t *at_in;
    int optflags = 0;
    int rc;
    int rc2;
    int rc3;
    int j;

    h_in = api->open_file_read(filepath, filetype, &natoms);
    at_in = (molfile_atom_t *)malloc(natoms * sizeof(molfile_atom_t));
    ts_in.coords = (float *)malloc(3 * natoms * sizeof(float));
    rc3 = api->read_structure(h_in, &optflags, at_in);

    rc = api->read_next_timestep(h_in, natoms, &ts_in);
    //rc2 = api->read_timestep(h_in,natoms, &ts_in,&metaqm_in,&qm_ts_in);

    for (j = 0; j < 20; j++)
    {
        printf("%d## ", j);
        printf("%f|%f|%f\n", ts_in.coords[3 * j], ts_in.coords[3 * j + 1], ts_in.coords[3 * j + 2]);
        printf("resname : %s\t", at_in[j].resname);
        printf("chain : %s\t", at_in[j].chain);
        printf("atomic nb : %d\n", at_in[j].atomicnumber);
    }
    //printf("RC : %d\n", rc);
    printf("{%f} \t", ts_in.coords[0]);
    printf("%d\t", natoms);
    printf("%s | %s |%d\n", filepath, filetype, natoms);

    api->close_file_read(h_in);

}