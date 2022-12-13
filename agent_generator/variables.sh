#!/bin/bash

cmd_pkg_map=(
    "fence_apc:fence-agents-apc"
    "fence_apc_snmp:fence-agents-apc-snmp"
    "fence_amt:None"
    "fence_bladecenter:fence-agents-bladecenter"
    "fence_brocade:fence-agents-brocade"
    "fence_cisco_mds:fence-agents-cisco-mds"
    "fence_cisco_ucs:fence-agents-cisco-ucs"
    "fence_compute:fence-agents-compute"
    "fence_crosslink:None"
    "fence_drac5:fence-agents-drac5"
    "fence_eaton_snmp:fence-agents-eaton-snmp"
    "fence_eps:fence-agents-eps"
    "fence_hpblade:fence-agents-hpblade"
    "fence_ibmblade:fence-agents-ibmblade"
    "fence_idrac:fence-agents-ipmilan"
    "fence_ifmib:fence-agents-ifmib"
    "fence_ilo:fence-agents-ilo2"
    "fence_ilo2:fence-agents-ilo2"
    "fence_ilo3:fence-agents-ipmilan"
    "fence_ilo4:fence-agents-ipmilan"
    "fence_ilo_mp:fence-agents-ilo-mp"
    "fence_imm:fence-agents-ipmilan"
    "fence_intelmodular:fence-agents-intelmodular"
    "fence_ipdu:fence-agents-ipdu"
    "fence_ipmilan:fence-agents-ipmilan"
    "fence_ironic:None"
    "fence_kdump:fence-agents-kdump"
    "fence_kubevirt:None"
    "fence_redfish:fence-agents-redfish"
    "fence_rhevm:fence-agents-rhevm"
    "fence_rsb:fence-agents-rsb"
    "fence_scsi:fence-agents-scsi"
    "fence_virt:fence-virt"
    "fence_vmware_soap:fence-agents-vmware-soap"
    "fence_watchdog:fence-agents-sbd"
    "fence_wti:fence-agents-wti"

    # These have manual changes and need to be updated manually:
    # "fence_xvm:fence-virt"

    # re fence_kubevirt:
    # change to fence-agents-kubevirt when we have it with
    # https://bugzilla.redhat.com/show_bug.cgi?id=1984803
)
