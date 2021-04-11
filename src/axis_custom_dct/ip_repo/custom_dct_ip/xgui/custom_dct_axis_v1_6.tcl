# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "COEFF_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_AXIS_TDATA_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "DATA_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "FIRST_STAGE_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "QUANT_STAGE_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "SECOND_STAGE_WIDTH" -parent ${Page_0}


}

proc update_PARAM_VALUE.COEFF_WIDTH { PARAM_VALUE.COEFF_WIDTH } {
	# Procedure called to update COEFF_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.COEFF_WIDTH { PARAM_VALUE.COEFF_WIDTH } {
	# Procedure called to validate COEFF_WIDTH
	return true
}

proc update_PARAM_VALUE.C_AXIS_TDATA_WIDTH { PARAM_VALUE.C_AXIS_TDATA_WIDTH } {
	# Procedure called to update C_AXIS_TDATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_AXIS_TDATA_WIDTH { PARAM_VALUE.C_AXIS_TDATA_WIDTH } {
	# Procedure called to validate C_AXIS_TDATA_WIDTH
	return true
}

proc update_PARAM_VALUE.DATA_WIDTH { PARAM_VALUE.DATA_WIDTH } {
	# Procedure called to update DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DATA_WIDTH { PARAM_VALUE.DATA_WIDTH } {
	# Procedure called to validate DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.FIRST_STAGE_WIDTH { PARAM_VALUE.FIRST_STAGE_WIDTH } {
	# Procedure called to update FIRST_STAGE_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.FIRST_STAGE_WIDTH { PARAM_VALUE.FIRST_STAGE_WIDTH } {
	# Procedure called to validate FIRST_STAGE_WIDTH
	return true
}

proc update_PARAM_VALUE.QUANT_STAGE_WIDTH { PARAM_VALUE.QUANT_STAGE_WIDTH } {
	# Procedure called to update QUANT_STAGE_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.QUANT_STAGE_WIDTH { PARAM_VALUE.QUANT_STAGE_WIDTH } {
	# Procedure called to validate QUANT_STAGE_WIDTH
	return true
}

proc update_PARAM_VALUE.SECOND_STAGE_WIDTH { PARAM_VALUE.SECOND_STAGE_WIDTH } {
	# Procedure called to update SECOND_STAGE_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SECOND_STAGE_WIDTH { PARAM_VALUE.SECOND_STAGE_WIDTH } {
	# Procedure called to validate SECOND_STAGE_WIDTH
	return true
}


proc update_MODELPARAM_VALUE.C_AXIS_TDATA_WIDTH { MODELPARAM_VALUE.C_AXIS_TDATA_WIDTH PARAM_VALUE.C_AXIS_TDATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_AXIS_TDATA_WIDTH}] ${MODELPARAM_VALUE.C_AXIS_TDATA_WIDTH}
}

proc update_MODELPARAM_VALUE.DATA_WIDTH { MODELPARAM_VALUE.DATA_WIDTH PARAM_VALUE.DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DATA_WIDTH}] ${MODELPARAM_VALUE.DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.COEFF_WIDTH { MODELPARAM_VALUE.COEFF_WIDTH PARAM_VALUE.COEFF_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.COEFF_WIDTH}] ${MODELPARAM_VALUE.COEFF_WIDTH}
}

proc update_MODELPARAM_VALUE.FIRST_STAGE_WIDTH { MODELPARAM_VALUE.FIRST_STAGE_WIDTH PARAM_VALUE.FIRST_STAGE_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.FIRST_STAGE_WIDTH}] ${MODELPARAM_VALUE.FIRST_STAGE_WIDTH}
}

proc update_MODELPARAM_VALUE.SECOND_STAGE_WIDTH { MODELPARAM_VALUE.SECOND_STAGE_WIDTH PARAM_VALUE.SECOND_STAGE_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SECOND_STAGE_WIDTH}] ${MODELPARAM_VALUE.SECOND_STAGE_WIDTH}
}

proc update_MODELPARAM_VALUE.QUANT_STAGE_WIDTH { MODELPARAM_VALUE.QUANT_STAGE_WIDTH PARAM_VALUE.QUANT_STAGE_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.QUANT_STAGE_WIDTH}] ${MODELPARAM_VALUE.QUANT_STAGE_WIDTH}
}

