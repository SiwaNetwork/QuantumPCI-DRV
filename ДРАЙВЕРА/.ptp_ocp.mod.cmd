savedcmd_ptp_ocp.mod := printf '%s\n'   ptp_ocp.o | awk '!x[$$0]++ { print("./"$$0) }' > ptp_ocp.mod
