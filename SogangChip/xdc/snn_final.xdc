#create_pblock pblock_my_snn_axi_0
#add_cells_to_pblock [get_pblocks pblock_my_snn_axi_0] [get_cells -quiet [list design_1_i/my_snn_axi_0]]
#resize_pblock [get_pblocks pblock_my_snn_axi_0] -add {SLICE_X26Y66:SLICE_X95Y131}
#resize_pblock [get_pblocks pblock_my_snn_axi_0] -add {DSP48_X2Y28:DSP48_X3Y51}
#resize_pblock [get_pblocks pblock_my_snn_axi_0] -add {RAMB18_X2Y28:RAMB18_X4Y51}
#resize_pblock [get_pblocks pblock_my_snn_axi_0] -add {RAMB36_X2Y14:RAMB36_X4Y25}
