#ifndef LIBMOLFILE_PLUGIN_H
#define LIBMOLFILE_PLUGIN_H
#include "vmdplugin.h"

#ifdef __cplusplus
extern "C" {
#endif

extern int molfile_crdplugin_init(void);
extern int molfile_crdplugin_register(void *, vmdplugin_register_cb);
extern int molfile_crdplugin_fini(void);
extern int molfile_dcdplugin_init(void);
extern int molfile_dcdplugin_register(void *, vmdplugin_register_cb);
extern int molfile_dcdplugin_fini(void);
extern int molfile_gromacsplugin_init(void);
extern int molfile_gromacsplugin_register(void *, vmdplugin_register_cb);
extern int molfile_gromacsplugin_fini(void);
extern int molfile_namdbinplugin_init(void);
extern int molfile_namdbinplugin_register(void *, vmdplugin_register_cb);
extern int molfile_namdbinplugin_fini(void);
extern int molfile_parm7plugin_init(void);
extern int molfile_parm7plugin_register(void *, vmdplugin_register_cb);
extern int molfile_parm7plugin_fini(void);
extern int molfile_parmplugin_init(void);
extern int molfile_parmplugin_register(void *, vmdplugin_register_cb);
extern int molfile_parmplugin_fini(void);
extern int molfile_pdbplugin_init(void);
extern int molfile_pdbplugin_register(void *, vmdplugin_register_cb);
extern int molfile_pdbplugin_fini(void);
extern int molfile_pdbxplugin_init(void);
extern int molfile_pdbxplugin_register(void *, vmdplugin_register_cb);
extern int molfile_pdbxplugin_fini(void);
extern int molfile_psfplugin_init(void);
extern int molfile_psfplugin_register(void *, vmdplugin_register_cb);
extern int molfile_psfplugin_fini(void);
extern int molfile_rst7plugin_init(void);
extern int molfile_rst7plugin_register(void *, vmdplugin_register_cb);
extern int molfile_rst7plugin_fini(void);
extern int molfile_dtrplugin_init(void);
extern int molfile_dtrplugin_register(void *, vmdplugin_register_cb);
extern int molfile_dtrplugin_fini(void);
extern int molfile_maeffplugin_init(void);
extern int molfile_maeffplugin_register(void *, vmdplugin_register_cb);
extern int molfile_maeffplugin_fini(void);
extern int molfile_netcdfplugin_init(void);
extern int molfile_netcdfplugin_register(void *, vmdplugin_register_cb);
extern int molfile_netcdfplugin_fini(void);
extern int molfile_vtfplugin_init(void);
extern int molfile_vtfplugin_register(void *, vmdplugin_register_cb);
extern int molfile_vtfplugin_fini(void);
extern int molfile_webpdbplugin_init(void);
extern int molfile_webpdbplugin_register(void *, vmdplugin_register_cb);
extern int molfile_webpdbplugin_fini(void);

#define MOLFILE_INIT_ALL \
    molfile_crdplugin_init(); \
    molfile_dcdplugin_init(); \
    molfile_gromacsplugin_init(); \
    molfile_namdbinplugin_init(); \
    molfile_parm7plugin_init(); \
    molfile_parmplugin_init(); \
    molfile_pdbplugin_init(); \
    molfile_pdbxplugin_init(); \
    molfile_psfplugin_init(); \
    molfile_rst7plugin_init(); \
    molfile_dtrplugin_init(); \
    molfile_maeffplugin_init(); \
    molfile_netcdfplugin_init(); \
    molfile_vtfplugin_init(); \
    molfile_webpdbplugin_init(); \

#define MOLFILE_REGISTER_ALL(v, cb) \
    molfile_crdplugin_register(v, cb); \
    molfile_dcdplugin_register(v, cb); \
    molfile_gromacsplugin_register(v, cb); \
    molfile_namdbinplugin_register(v, cb); \
    molfile_parm7plugin_register(v, cb); \
    molfile_parmplugin_register(v, cb); \
    molfile_pdbplugin_register(v, cb); \
    molfile_pdbxplugin_register(v, cb); \
    molfile_psfplugin_register(v, cb); \
    molfile_rst7plugin_register(v, cb); \
    molfile_dtrplugin_register(v, cb); \
    molfile_maeffplugin_register(v, cb); \
    molfile_netcdfplugin_register(v, cb); \
    molfile_vtfplugin_register(v, cb); \
    molfile_webpdbplugin_register(v, cb); \

#define MOLFILE_FINI_ALL \
    molfile_crdplugin_fini(); \
    molfile_dcdplugin_fini(); \
    molfile_gromacsplugin_fini(); \
    molfile_namdbinplugin_fini(); \
    molfile_parm7plugin_fini(); \
    molfile_parmplugin_fini(); \
    molfile_pdbplugin_fini(); \
    molfile_pdbxplugin_fini(); \
    molfile_psfplugin_fini(); \
    molfile_rst7plugin_fini(); \
    molfile_dtrplugin_fini(); \
    molfile_maeffplugin_fini(); \
    molfile_netcdfplugin_fini(); \
    molfile_vtfplugin_fini(); \
    molfile_webpdbplugin_fini(); \

#ifdef __cplusplus
}
#endif
#endif
