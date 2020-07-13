/***************************************************************************
 *cr
 *cr            (C) Copyright 1995-2006 The Board of Trustees of the
 *cr                        University of Illinois
 *cr                         All Rights Reserved
 *cr
 ***************************************************************************/

/***************************************************************************
 * RCS INFORMATION:
 *
 *      $RCSfile: molfile_plugin.h,v $
 *      $Author: johns $       $Locker:  $             $State: Exp $
 *      $Revision: 1.108 $       $Date: 2016/02/26 03:17:01 $
 *
 ***************************************************************************/

/** @file 
 * API for C extensions to define a way to control VMD rendering for inclusion
 * in third-party rendering workflows.
 */ 

#ifndef RENDER_PLUGIN_H
#define RENDER_PLUGIN_H

#include "vmdplugin.h"

/**
 * Define a common plugin type to be used when registering the plugin.
 */
#define RENDER_PLUGIN_TYPE "render control"

/* File plugin symbolic constants for better code readability */
#define RENDER_SUCCESS           0   /**< succeeded in reading file      */
#define RENDER_ERROR            -1   /**< error reading/opening a file   */

/** 
 * Camera definition in global coordinate system 
 */
typedef struct {
  Vector pos;    /**< camera position */
  Vector fwd;    /**< camera forward vector ("-Z" in OpenGL style) */
  Vector up;     /**< camera up vector ("+Y" in OpenGL style) */
  double fov_y;  /**< field-of-view in Y (vertical) axis (degrees) */

  /** XXX work on these some more       
  double scale;  /* global scale.  (in which sense?
                  * Does cale=0.1 make the camera small, 
                  * or make the world small?)
                  */

  int as_dome;    /**< 0=> planar projection, 1=> dome rendering */
} vcam_camdef_t;


/**
 * global read-only values that would be nice to know
 * Supposing there's a 4x4 matrix type called Matrix, and a 3-d Vector type
 */
typedef struct {
  Matrix mrotate;
  Matrix mcenter;
  Matrix mscale;
  Matrix mglobal;
  Vector vback;    // "back" translation of camera 
                   // (seems to be 0,0,-2 by default?)
                   // other stuff?  framebuffer resolution?  
                   // aspect ratio?   stereo separation in 
                   // camera-coordinate units?  Global scale?
} vcam_cam_globals_t;
   

// When we ask VMD to take a screen snapshot, what type?
typedef enum {
  SNAP_RGB8,        // grab a memory buffer and pass it to us, 
                    // of 8-bit RGB/RGBA pixels
                    // do we care about option of greater bit
                    // depths, like 16-bit or float per-channel?  
                    // Does VMD do rendering that would take 
                    // advantage of it?


  SNAP_PNG,         // Save as PNG image (or JPEG or TGA or PPM
                    // or whatever you support) 
                    // (with alpha if requested) JPEG? H264?

  // XXX add these?
  SNAP_PPM,         // 24-bit RGB PPM
  SNAP_PPM48,       // 48-bit RGB PPM
  SNAP_TGA,         // 24-bit RGB Targa
 vcam_snaptype_t;


// description of a snapshot after it's taken.
typedef struct {
   int xsize;         // image width
   int ysize;
   int channels;      // number of channels (3 or 4 for RGB vs RGBA)
   int bpchan;        // bytes per channel value (1 for 8-bit, 2 for 16-bit, 4 for float?)
   int bprow;         // bytes per row (may be bpchan*channels*xsize or a bit bigger if padded)

   void *data;        // pointer to image array.  
                      // Data owned by VMD - plugin shouldn't rely on 
                      // it existing after return?  and shouldn't write
                      // to it.  
                      // data may be NULL if we asked for 
                      // snapshot to be saved to an image file.
} vcam_snap_t;


// XXX I don't think we need this anymore
#define VCAM_VERSION 0x0100

// struct-full-of-callback-pointers, set at plugin initialization
typedef struct { 
  // magic number.  Allows checking for future-incompatible 
  // versions of this interface
  int version;

  // Ask VMD to render next frame using this camera viewpoint/setup.
  // I'm assuming we can't ask for a change in resolution, but 
  // can ask for a different FOV or dome/planar setup... OK?
  void (*set_cam)( vcam_camdef_t * );

  // Ask VMD to take a screen snapshot of next rendered frame.
  // VMD will call *us* back (vcam_snapped() below) when 
  // it's done, and tell us image resolution etc.
  // Assuming this is a one-shot - if we want more snapshots, 
  // we have to call this again for each frame
  // If VMD's framebuffer records alpha (even 0-vs-1 coverage),
  // it might be nice to allow passing that along.
  // If there's no alpha recorded there, then nevermind offering
  // that option.
  // filename would be NULL if we're asking for a raw RGB/RGBA buffer
  void (*take_snap)( vcam_snaptype_t style, int withalpha, char *filename );

  // ask for values of camera-related global variables, something like that?
  void (*get_cam_globals)( vcam_cam_globals_t * );
} vcam_init_t;


Functions in the plugin that VMD may call:
   void vcam_init( struct vcam_init_t * );
     // called once at startup.
     // If the plugin receives an interface version that it can't handle,
     // then it should ignore calls to any of the other entry points.
     void vcam_preframe();
    
     // may call the callbacks specified in the vcam_init_t structure
     void vcam_snapped( vcam_snap_t * );
     
     // called by VMD after a requested snapshot is complete
     void vcam_shutdown();
  }





/**
 * Main file reader API.  Any function in this struct may be NULL
 * if not implemented by the plugin; the application checks this to determine
 * what functionality is present in the plugin. 
 */ 
typedef struct {
  /**
   * Required header 
   */
  vmdplugin_HEAD

  /**
   * Filename extension for this file type.  May be NULL if no filename 
   * extension exists and/or is known.  For file types that match several
   * common extensions, list them in a comma separated list such as:
   *  "pdb,ent,foo,bar,baz,ban"
   * The comma separated list will be expanded when filename extension matching
   * is performed.  If multiple plugins solicit the same filename extensions,
   * the one that lists the extension earliest in its list is selected. In the 
   * case of a "tie", the first one tried/checked "wins".
   */
  const char *filename_extension;

#if 0
  // XXX insert stuff here



#endif

  /**
   *  Console output, READ-ONLY function pointer.
   *  Function pointer that plugins can use for printing to the host
   *  application's text console.  This provides a clean way for plugins
   *  to send message strings back to the calling application, giving the
   *  caller the ability to prioritize, buffer, and redirect console messages
   *  to an appropriate output channel, window, etc.  This enables the use of
   *  graphical consoles like TkCon without losing console output from plugins.
   *  If the function pointer is NULL, no console output service is provided
   *  by the calling application, and the output should default to stdout
   *  stream.  If the function pointer is non-NULL, all output will be
   *  subsequently dealt with by the calling application.
   *
   *  XXX this should really be put into a separate block of
   *      application-provided read-only function pointers for any
   *      application-provided services
   */
  int (* cons_fputs)(const int, const char*);

} molfile_plugin_t;

#endif

