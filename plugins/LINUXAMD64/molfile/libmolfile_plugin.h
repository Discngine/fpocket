#ifndef LIBMOLFILE_PLUGIN_H
#define LIBMOLFILE_PLUGIN_H
#include "vmdplugin.h"

#ifdef __cplusplus
extern "C" {
#endif

extern int molfile_abinitplugin_init(void);
extern int molfile_abinitplugin_register(void *, vmdplugin_register_cb);
extern int molfile_abinitplugin_fini(void);
extern int molfile_amiraplugin_init(void);
extern int molfile_amiraplugin_register(void *, vmdplugin_register_cb);
extern int molfile_amiraplugin_fini(void);
extern int molfile_avsplugin_init(void);
extern int molfile_avsplugin_register(void *, vmdplugin_register_cb);
extern int molfile_avsplugin_fini(void);
extern int molfile_babelplugin_init(void);
extern int molfile_babelplugin_register(void *, vmdplugin_register_cb);
extern int molfile_babelplugin_fini(void);
extern int molfile_basissetplugin_init(void);
extern int molfile_basissetplugin_register(void *, vmdplugin_register_cb);
extern int molfile_basissetplugin_fini(void);
extern int molfile_bgfplugin_init(void);
extern int molfile_bgfplugin_register(void *, vmdplugin_register_cb);
extern int molfile_bgfplugin_fini(void);
extern int molfile_binposplugin_init(void);
extern int molfile_binposplugin_register(void *, vmdplugin_register_cb);
extern int molfile_binposplugin_fini(void);
extern int molfile_biomoccaplugin_init(void);
extern int molfile_biomoccaplugin_register(void *, vmdplugin_register_cb);
extern int molfile_biomoccaplugin_fini(void);
extern int molfile_brixplugin_init(void);
extern int molfile_brixplugin_register(void *, vmdplugin_register_cb);
extern int molfile_brixplugin_fini(void);
extern int molfile_carplugin_init(void);
extern int molfile_carplugin_register(void *, vmdplugin_register_cb);
extern int molfile_carplugin_fini(void);
extern int molfile_ccp4plugin_init(void);
extern int molfile_ccp4plugin_register(void *, vmdplugin_register_cb);
extern int molfile_ccp4plugin_fini(void);
extern int molfile_corplugin_init(void);
extern int molfile_corplugin_register(void *, vmdplugin_register_cb);
extern int molfile_corplugin_fini(void);
extern int molfile_cpmdplugin_init(void);
extern int molfile_cpmdplugin_register(void *, vmdplugin_register_cb);
extern int molfile_cpmdplugin_fini(void);
extern int molfile_crdplugin_init(void);
extern int molfile_crdplugin_register(void *, vmdplugin_register_cb);
extern int molfile_crdplugin_fini(void);
extern int molfile_cubeplugin_init(void);
extern int molfile_cubeplugin_register(void *, vmdplugin_register_cb);
extern int molfile_cubeplugin_fini(void);
extern int molfile_dcdplugin_init(void);
extern int molfile_dcdplugin_register(void *, vmdplugin_register_cb);
extern int molfile_dcdplugin_fini(void);
extern int molfile_dlpolyplugin_init(void);
extern int molfile_dlpolyplugin_register(void *, vmdplugin_register_cb);
extern int molfile_dlpolyplugin_fini(void);
extern int molfile_dsn6plugin_init(void);
extern int molfile_dsn6plugin_register(void *, vmdplugin_register_cb);
extern int molfile_dsn6plugin_fini(void);
extern int molfile_dxplugin_init(void);
extern int molfile_dxplugin_register(void *, vmdplugin_register_cb);
extern int molfile_dxplugin_fini(void);
extern int molfile_edmplugin_init(void);
extern int molfile_edmplugin_register(void *, vmdplugin_register_cb);
extern int molfile_edmplugin_fini(void);
extern int molfile_fs4plugin_init(void);
extern int molfile_fs4plugin_register(void *, vmdplugin_register_cb);
extern int molfile_fs4plugin_fini(void);
extern int molfile_gamessplugin_init(void);
extern int molfile_gamessplugin_register(void *, vmdplugin_register_cb);
extern int molfile_gamessplugin_fini(void);
extern int molfile_graspplugin_init(void);
extern int molfile_graspplugin_register(void *, vmdplugin_register_cb);
extern int molfile_graspplugin_fini(void);
extern int molfile_grdplugin_init(void);
extern int molfile_grdplugin_register(void *, vmdplugin_register_cb);
extern int molfile_grdplugin_fini(void);
extern int molfile_gridplugin_init(void);
extern int molfile_gridplugin_register(void *, vmdplugin_register_cb);
extern int molfile_gridplugin_fini(void);
extern int molfile_gromacsplugin_init(void);
extern int molfile_gromacsplugin_register(void *, vmdplugin_register_cb);
extern int molfile_gromacsplugin_fini(void);
extern int molfile_jsplugin_init(void);
extern int molfile_jsplugin_register(void *, vmdplugin_register_cb);
extern int molfile_jsplugin_fini(void);
extern int molfile_lammpsplugin_init(void);
extern int molfile_lammpsplugin_register(void *, vmdplugin_register_cb);
extern int molfile_lammpsplugin_fini(void);
extern int molfile_mapplugin_init(void);
extern int molfile_mapplugin_register(void *, vmdplugin_register_cb);
extern int molfile_mapplugin_fini(void);
extern int molfile_mdfplugin_init(void);
extern int molfile_mdfplugin_register(void *, vmdplugin_register_cb);
extern int molfile_mdfplugin_fini(void);
extern int molfile_mol2plugin_init(void);
extern int molfile_mol2plugin_register(void *, vmdplugin_register_cb);
extern int molfile_mol2plugin_fini(void);
extern int molfile_moldenplugin_init(void);
extern int molfile_moldenplugin_register(void *, vmdplugin_register_cb);
extern int molfile_moldenplugin_fini(void);
extern int molfile_molemeshplugin_init(void);
extern int molfile_molemeshplugin_register(void *, vmdplugin_register_cb);
extern int molfile_molemeshplugin_fini(void);
extern int molfile_msmsplugin_init(void);
extern int molfile_msmsplugin_register(void *, vmdplugin_register_cb);
extern int molfile_msmsplugin_fini(void);
extern int molfile_namdbinplugin_init(void);
extern int molfile_namdbinplugin_register(void *, vmdplugin_register_cb);
extern int molfile_namdbinplugin_fini(void);
extern int molfile_offplugin_init(void);
extern int molfile_offplugin_register(void *, vmdplugin_register_cb);
extern int molfile_offplugin_fini(void);
extern int molfile_parm7plugin_init(void);
extern int molfile_parm7plugin_register(void *, vmdplugin_register_cb);
extern int molfile_parm7plugin_fini(void);
extern int molfile_parmplugin_init(void);
extern int molfile_parmplugin_register(void *, vmdplugin_register_cb);
extern int molfile_parmplugin_fini(void);
extern int molfile_pbeqplugin_init(void);
extern int molfile_pbeqplugin_register(void *, vmdplugin_register_cb);
extern int molfile_pbeqplugin_fini(void);
extern int molfile_pdbplugin_init(void);
extern int molfile_pdbplugin_register(void *, vmdplugin_register_cb);
extern int molfile_pdbplugin_fini(void);
extern int molfile_pdbxplugin_init(void);
extern int molfile_pdbxplugin_register(void *, vmdplugin_register_cb);
extern int molfile_pdbxplugin_fini(void);
extern int molfile_phiplugin_init(void);
extern int molfile_phiplugin_register(void *, vmdplugin_register_cb);
extern int molfile_phiplugin_fini(void);
extern int molfile_pltplugin_init(void);
extern int molfile_pltplugin_register(void *, vmdplugin_register_cb);
extern int molfile_pltplugin_fini(void);
extern int molfile_plyplugin_init(void);
extern int molfile_plyplugin_register(void *, vmdplugin_register_cb);
extern int molfile_plyplugin_fini(void);
extern int molfile_pqrplugin_init(void);
extern int molfile_pqrplugin_register(void *, vmdplugin_register_cb);
extern int molfile_pqrplugin_fini(void);
extern int molfile_psfplugin_init(void);
extern int molfile_psfplugin_register(void *, vmdplugin_register_cb);
extern int molfile_psfplugin_fini(void);
extern int molfile_raster3dplugin_init(void);
extern int molfile_raster3dplugin_register(void *, vmdplugin_register_cb);
extern int molfile_raster3dplugin_fini(void);
extern int molfile_rst7plugin_init(void);
extern int molfile_rst7plugin_register(void *, vmdplugin_register_cb);
extern int molfile_rst7plugin_fini(void);
extern int molfile_situsplugin_init(void);
extern int molfile_situsplugin_register(void *, vmdplugin_register_cb);
extern int molfile_situsplugin_fini(void);
extern int molfile_spiderplugin_init(void);
extern int molfile_spiderplugin_register(void *, vmdplugin_register_cb);
extern int molfile_spiderplugin_fini(void);
extern int molfile_stlplugin_init(void);
extern int molfile_stlplugin_register(void *, vmdplugin_register_cb);
extern int molfile_stlplugin_fini(void);
extern int molfile_tinkerplugin_init(void);
extern int molfile_tinkerplugin_register(void *, vmdplugin_register_cb);
extern int molfile_tinkerplugin_fini(void);
extern int molfile_uhbdplugin_init(void);
extern int molfile_uhbdplugin_register(void *, vmdplugin_register_cb);
extern int molfile_uhbdplugin_fini(void);
extern int molfile_vaspchgcarplugin_init(void);
extern int molfile_vaspchgcarplugin_register(void *, vmdplugin_register_cb);
extern int molfile_vaspchgcarplugin_fini(void);
extern int molfile_vaspoutcarplugin_init(void);
extern int molfile_vaspoutcarplugin_register(void *, vmdplugin_register_cb);
extern int molfile_vaspoutcarplugin_fini(void);
extern int molfile_vaspparchgplugin_init(void);
extern int molfile_vaspparchgplugin_register(void *, vmdplugin_register_cb);
extern int molfile_vaspparchgplugin_fini(void);
extern int molfile_vaspposcarplugin_init(void);
extern int molfile_vaspposcarplugin_register(void *, vmdplugin_register_cb);
extern int molfile_vaspposcarplugin_fini(void);
extern int molfile_vasp5xdatcarplugin_init(void);
extern int molfile_vasp5xdatcarplugin_register(void *, vmdplugin_register_cb);
extern int molfile_vasp5xdatcarplugin_fini(void);
extern int molfile_vaspxdatcarplugin_init(void);
extern int molfile_vaspxdatcarplugin_register(void *, vmdplugin_register_cb);
extern int molfile_vaspxdatcarplugin_fini(void);
extern int molfile_vaspxmlplugin_init(void);
extern int molfile_vaspxmlplugin_register(void *, vmdplugin_register_cb);
extern int molfile_vaspxmlplugin_fini(void);
extern int molfile_vtkplugin_init(void);
extern int molfile_vtkplugin_register(void *, vmdplugin_register_cb);
extern int molfile_vtkplugin_fini(void);
extern int molfile_xbgfplugin_init(void);
extern int molfile_xbgfplugin_register(void *, vmdplugin_register_cb);
extern int molfile_xbgfplugin_fini(void);
extern int molfile_xsfplugin_init(void);
extern int molfile_xsfplugin_register(void *, vmdplugin_register_cb);
extern int molfile_xsfplugin_fini(void);
extern int molfile_xyzplugin_init(void);
extern int molfile_xyzplugin_register(void *, vmdplugin_register_cb);
extern int molfile_xyzplugin_fini(void);
extern int molfile_dtrplugin_init(void);
extern int molfile_dtrplugin_register(void *, vmdplugin_register_cb);
extern int molfile_dtrplugin_fini(void);
extern int molfile_maeffplugin_init(void);
extern int molfile_maeffplugin_register(void *, vmdplugin_register_cb);
extern int molfile_maeffplugin_fini(void);
extern int molfile_orcaplugin_init(void);
extern int molfile_orcaplugin_register(void *, vmdplugin_register_cb);
extern int molfile_orcaplugin_fini(void);

#define MOLFILE_INIT_ALL \
    molfile_abinitplugin_init(); \
    molfile_amiraplugin_init(); \
    molfile_avsplugin_init(); \
    molfile_babelplugin_init(); \
    molfile_basissetplugin_init(); \
    molfile_bgfplugin_init(); \
    molfile_binposplugin_init(); \
    molfile_biomoccaplugin_init(); \
    molfile_brixplugin_init(); \
    molfile_carplugin_init(); \
    molfile_ccp4plugin_init(); \
    molfile_corplugin_init(); \
    molfile_cpmdplugin_init(); \
    molfile_crdplugin_init(); \
    molfile_cubeplugin_init(); \
    molfile_dcdplugin_init(); \
    molfile_dlpolyplugin_init(); \
    molfile_dsn6plugin_init(); \
    molfile_dxplugin_init(); \
    molfile_edmplugin_init(); \
    molfile_fs4plugin_init(); \
    molfile_gamessplugin_init(); \
    molfile_graspplugin_init(); \
    molfile_grdplugin_init(); \
    molfile_gridplugin_init(); \
    molfile_gromacsplugin_init(); \
    molfile_jsplugin_init(); \
    molfile_lammpsplugin_init(); \
    molfile_mapplugin_init(); \
    molfile_mdfplugin_init(); \
    molfile_mol2plugin_init(); \
    molfile_moldenplugin_init(); \
    molfile_molemeshplugin_init(); \
    molfile_msmsplugin_init(); \
    molfile_namdbinplugin_init(); \
    molfile_offplugin_init(); \
    molfile_parm7plugin_init(); \
    molfile_parmplugin_init(); \
    molfile_pbeqplugin_init(); \
    molfile_pdbplugin_init(); \
    molfile_pdbxplugin_init(); \
    molfile_phiplugin_init(); \
    molfile_pltplugin_init(); \
    molfile_plyplugin_init(); \
    molfile_pqrplugin_init(); \
    molfile_psfplugin_init(); \
    molfile_raster3dplugin_init(); \
    molfile_rst7plugin_init(); \
    molfile_situsplugin_init(); \
    molfile_spiderplugin_init(); \
    molfile_stlplugin_init(); \
    molfile_tinkerplugin_init(); \
    molfile_uhbdplugin_init(); \
    molfile_vaspchgcarplugin_init(); \
    molfile_vaspoutcarplugin_init(); \
    molfile_vaspparchgplugin_init(); \
    molfile_vaspposcarplugin_init(); \
    molfile_vasp5xdatcarplugin_init(); \
    molfile_vaspxdatcarplugin_init(); \
    molfile_vaspxmlplugin_init(); \
    molfile_vtkplugin_init(); \
    molfile_xbgfplugin_init(); \
    molfile_xsfplugin_init(); \
    molfile_xyzplugin_init(); \
    molfile_dtrplugin_init(); \
    molfile_maeffplugin_init(); \
    molfile_orcaplugin_init(); \

#define MOLFILE_REGISTER_ALL(v, cb) \
    molfile_abinitplugin_register(v, cb); \
    molfile_amiraplugin_register(v, cb); \
    molfile_avsplugin_register(v, cb); \
    molfile_babelplugin_register(v, cb); \
    molfile_basissetplugin_register(v, cb); \
    molfile_bgfplugin_register(v, cb); \
    molfile_binposplugin_register(v, cb); \
    molfile_biomoccaplugin_register(v, cb); \
    molfile_brixplugin_register(v, cb); \
    molfile_carplugin_register(v, cb); \
    molfile_ccp4plugin_register(v, cb); \
    molfile_corplugin_register(v, cb); \
    molfile_cpmdplugin_register(v, cb); \
    molfile_crdplugin_register(v, cb); \
    molfile_cubeplugin_register(v, cb); \
    molfile_dcdplugin_register(v, cb); \
    molfile_dlpolyplugin_register(v, cb); \
    molfile_dsn6plugin_register(v, cb); \
    molfile_dxplugin_register(v, cb); \
    molfile_edmplugin_register(v, cb); \
    molfile_fs4plugin_register(v, cb); \
    molfile_gamessplugin_register(v, cb); \
    molfile_graspplugin_register(v, cb); \
    molfile_grdplugin_register(v, cb); \
    molfile_gridplugin_register(v, cb); \
    molfile_gromacsplugin_register(v, cb); \
    molfile_jsplugin_register(v, cb); \
    molfile_lammpsplugin_register(v, cb); \
    molfile_mapplugin_register(v, cb); \
    molfile_mdfplugin_register(v, cb); \
    molfile_mol2plugin_register(v, cb); \
    molfile_moldenplugin_register(v, cb); \
    molfile_molemeshplugin_register(v, cb); \
    molfile_msmsplugin_register(v, cb); \
    molfile_namdbinplugin_register(v, cb); \
    molfile_offplugin_register(v, cb); \
    molfile_parm7plugin_register(v, cb); \
    molfile_parmplugin_register(v, cb); \
    molfile_pbeqplugin_register(v, cb); \
    molfile_pdbplugin_register(v, cb); \
    molfile_pdbxplugin_register(v, cb); \
    molfile_phiplugin_register(v, cb); \
    molfile_pltplugin_register(v, cb); \
    molfile_plyplugin_register(v, cb); \
    molfile_pqrplugin_register(v, cb); \
    molfile_psfplugin_register(v, cb); \
    molfile_raster3dplugin_register(v, cb); \
    molfile_rst7plugin_register(v, cb); \
    molfile_situsplugin_register(v, cb); \
    molfile_spiderplugin_register(v, cb); \
    molfile_stlplugin_register(v, cb); \
    molfile_tinkerplugin_register(v, cb); \
    molfile_uhbdplugin_register(v, cb); \
    molfile_vaspchgcarplugin_register(v, cb); \
    molfile_vaspoutcarplugin_register(v, cb); \
    molfile_vaspparchgplugin_register(v, cb); \
    molfile_vaspposcarplugin_register(v, cb); \
    molfile_vasp5xdatcarplugin_register(v, cb); \
    molfile_vaspxdatcarplugin_register(v, cb); \
    molfile_vaspxmlplugin_register(v, cb); \
    molfile_vtkplugin_register(v, cb); \
    molfile_xbgfplugin_register(v, cb); \
    molfile_xsfplugin_register(v, cb); \
    molfile_xyzplugin_register(v, cb); \
    molfile_dtrplugin_register(v, cb); \
    molfile_maeffplugin_register(v, cb); \
    molfile_orcaplugin_register(v, cb); \

#define MOLFILE_FINI_ALL \
    molfile_abinitplugin_fini(); \
    molfile_amiraplugin_fini(); \
    molfile_avsplugin_fini(); \
    molfile_babelplugin_fini(); \
    molfile_basissetplugin_fini(); \
    molfile_bgfplugin_fini(); \
    molfile_binposplugin_fini(); \
    molfile_biomoccaplugin_fini(); \
    molfile_brixplugin_fini(); \
    molfile_carplugin_fini(); \
    molfile_ccp4plugin_fini(); \
    molfile_corplugin_fini(); \
    molfile_cpmdplugin_fini(); \
    molfile_crdplugin_fini(); \
    molfile_cubeplugin_fini(); \
    molfile_dcdplugin_fini(); \
    molfile_dlpolyplugin_fini(); \
    molfile_dsn6plugin_fini(); \
    molfile_dxplugin_fini(); \
    molfile_edmplugin_fini(); \
    molfile_fs4plugin_fini(); \
    molfile_gamessplugin_fini(); \
    molfile_graspplugin_fini(); \
    molfile_grdplugin_fini(); \
    molfile_gridplugin_fini(); \
    molfile_gromacsplugin_fini(); \
    molfile_jsplugin_fini(); \
    molfile_lammpsplugin_fini(); \
    molfile_mapplugin_fini(); \
    molfile_mdfplugin_fini(); \
    molfile_mol2plugin_fini(); \
    molfile_moldenplugin_fini(); \
    molfile_molemeshplugin_fini(); \
    molfile_msmsplugin_fini(); \
    molfile_namdbinplugin_fini(); \
    molfile_offplugin_fini(); \
    molfile_parm7plugin_fini(); \
    molfile_parmplugin_fini(); \
    molfile_pbeqplugin_fini(); \
    molfile_pdbplugin_fini(); \
    molfile_pdbxplugin_fini(); \
    molfile_phiplugin_fini(); \
    molfile_pltplugin_fini(); \
    molfile_plyplugin_fini(); \
    molfile_pqrplugin_fini(); \
    molfile_psfplugin_fini(); \
    molfile_raster3dplugin_fini(); \
    molfile_rst7plugin_fini(); \
    molfile_situsplugin_fini(); \
    molfile_spiderplugin_fini(); \
    molfile_stlplugin_fini(); \
    molfile_tinkerplugin_fini(); \
    molfile_uhbdplugin_fini(); \
    molfile_vaspchgcarplugin_fini(); \
    molfile_vaspoutcarplugin_fini(); \
    molfile_vaspparchgplugin_fini(); \
    molfile_vaspposcarplugin_fini(); \
    molfile_vasp5xdatcarplugin_fini(); \
    molfile_vaspxdatcarplugin_fini(); \
    molfile_vaspxmlplugin_fini(); \
    molfile_vtkplugin_fini(); \
    molfile_xbgfplugin_fini(); \
    molfile_xsfplugin_fini(); \
    molfile_xyzplugin_fini(); \
    molfile_dtrplugin_fini(); \
    molfile_maeffplugin_fini(); \
    molfile_orcaplugin_fini(); \

#ifdef __cplusplus
}
#endif
#endif
