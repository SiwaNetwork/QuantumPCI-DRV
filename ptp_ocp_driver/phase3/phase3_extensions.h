/*
 * Phase 3 Extensions Header
 * 
 * This header defines structures and interfaces for Phase 3 extensions:
 * - Network Integration
 * - IEEE 1588-2019 (PTP v2.1) Protocol
 * - NTP Stratum 1 Server
 * - Security Extensions
 */

#ifndef PTP_OCP_PHASE3_EXTENSIONS_H
#define PTP_OCP_PHASE3_EXTENSIONS_H

#include "../core/ptp_ocp_enhanced.h"

/* Network Integration */
extern int ptp_ocp_init_network_integration(struct ptp_ocp_enhanced *enhanced);
extern void ptp_ocp_cleanup_network_integration(struct ptp_ocp_enhanced *enhanced);

/* PTP v2.1 Protocol */
extern int ptp_v2_1_init_protocol(struct ptp_ocp_enhanced *enhanced);
extern void ptp_v2_1_cleanup_protocol(struct ptp_ocp_enhanced *enhanced);

/* NTP Stratum 1 Server */
extern int ntp_stratum1_init_server(struct ptp_ocp_enhanced *enhanced);
extern void ntp_stratum1_cleanup_server(struct ptp_ocp_enhanced *enhanced);

/* Phase 3 Configuration */
struct ptp_ocp_phase3_config {
    /* Network Integration */
    bool network_integration_enabled;
    bool intel_card_support;
    bool hardware_timestamping_enabled;
    
    /* PTP v2.1 Protocol */
    bool ptp_v2_1_enabled;
    u32 ptp_v2_1_domain;
    bool ptp_v2_1_security_enabled;
    
    /* NTP Stratum 1 Server */
    bool ntp_stratum1_enabled;
    u16 ntp_server_port;
    bool ntp_authentication_enabled;
    
    /* Security */
    bool security_enabled;
    bool audit_logging_enabled;
    u32 max_connections;
};

/* Phase 3 Statistics */
struct ptp_ocp_phase3_stats {
    /* Network Integration */
    u64 network_sync_events;
    u64 network_errors;
    u64 hardware_timestamp_events;
    
    /* PTP v2.1 Protocol */
    u64 ptp_v2_1_messages_sent;
    u64 ptp_v2_1_messages_received;
    u64 ptp_v2_1_security_failures;
    
    /* NTP Stratum 1 Server */
    u64 ntp_requests_handled;
    u64 ntp_responses_sent;
    u64 ntp_clients_connected;
    
    /* Security */
    u64 security_events;
    u64 authentication_failures;
    u64 audit_events;
};

#endif /* PTP_OCP_PHASE3_EXTENSIONS_H */

