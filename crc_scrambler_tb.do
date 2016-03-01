vlib work
vmap work work


vcom -work work crc_scrambler.vhd
vcom -work work crc3_tst.vhd


vsim -novopt crc3_tst
add wave -position insertpoint sim:/crc3_tst/*


radix -hex
view wave
run 300us
quit

