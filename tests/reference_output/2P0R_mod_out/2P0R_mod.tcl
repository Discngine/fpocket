proc highlighting { colorId representation id selection } {
   puts "highlighting $id"
   mol representation $representation
   mol material "Diffuse" 
    mol color $colorId
   mol selection $selection
   mol addrep $id
}

set id [mol new 2P0R_mod_out.pdb type pdb]
mol delrep top $id
highlighting Name "Lines" $id "protein"
highlighting Name "Licorice" $id "not protein and not resname STP"
highlighting Element "NewCartoon" $id "protein"
highlighting "ColorID 7" "VdW 0.4" $id "protein and occupancy>0.95"
set id [mol new 2P0R_mod_pockets.pqr type pqr]
                        mol selection "all" 
                         mol material "Glass3" 
                         mol delrep top $id 
                         mol representation "QuickSurf 0.3" 
                         mol color ResId $id 
                         mol addrep $id 
highlighting Index "Points 1" $id "resname STP"
display rendermode GLSL
