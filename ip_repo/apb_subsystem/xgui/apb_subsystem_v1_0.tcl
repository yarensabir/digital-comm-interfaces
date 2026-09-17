# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "I2C_CLK_DIV" -parent ${Page_0}
  ipgui::add_param $IPINST -name "SPI_CLK_DIV" -parent ${Page_0}
  ipgui::add_param $IPINST -name "UART_CLKS_PER_BIT" -parent ${Page_0}


}

proc update_PARAM_VALUE.I2C_CLK_DIV { PARAM_VALUE.I2C_CLK_DIV } {
	# Procedure called to update I2C_CLK_DIV when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.I2C_CLK_DIV { PARAM_VALUE.I2C_CLK_DIV } {
	# Procedure called to validate I2C_CLK_DIV
	return true
}

proc update_PARAM_VALUE.SPI_CLK_DIV { PARAM_VALUE.SPI_CLK_DIV } {
	# Procedure called to update SPI_CLK_DIV when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SPI_CLK_DIV { PARAM_VALUE.SPI_CLK_DIV } {
	# Procedure called to validate SPI_CLK_DIV
	return true
}

proc update_PARAM_VALUE.UART_CLKS_PER_BIT { PARAM_VALUE.UART_CLKS_PER_BIT } {
	# Procedure called to update UART_CLKS_PER_BIT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.UART_CLKS_PER_BIT { PARAM_VALUE.UART_CLKS_PER_BIT } {
	# Procedure called to validate UART_CLKS_PER_BIT
	return true
}


proc update_MODELPARAM_VALUE.UART_CLKS_PER_BIT { MODELPARAM_VALUE.UART_CLKS_PER_BIT PARAM_VALUE.UART_CLKS_PER_BIT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.UART_CLKS_PER_BIT}] ${MODELPARAM_VALUE.UART_CLKS_PER_BIT}
}

proc update_MODELPARAM_VALUE.SPI_CLK_DIV { MODELPARAM_VALUE.SPI_CLK_DIV PARAM_VALUE.SPI_CLK_DIV } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SPI_CLK_DIV}] ${MODELPARAM_VALUE.SPI_CLK_DIV}
}

proc update_MODELPARAM_VALUE.I2C_CLK_DIV { MODELPARAM_VALUE.I2C_CLK_DIV PARAM_VALUE.I2C_CLK_DIV } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.I2C_CLK_DIV}] ${MODELPARAM_VALUE.I2C_CLK_DIV}
}

