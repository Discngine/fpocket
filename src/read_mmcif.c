#include "../headers/read_mmcif.h"

static const char *ST_keep_hetatm[] = {

    "HEA", "HBI", "BIO", "CFM", "CLP", "FES", "F3S", "FS3", "FS4", "BPH",
    "BPB", "BCL", "BCB", "COB", "ZN", "FEA", "FEO", "H4B", "BH4", "BHS",
    "HBL", "THB", "DDH", "DHE", "HAS", "HDD", "HDM", "HEB", "HEC", "HEO",
    "HES", "HEV", "MHM", "SRM", "VER", "1FH", "2FH", "HC0", "HC1", "HF3",
    "HF5", "NFS", "OMO", "PHF", "SF3", "SF4", "CFM", "CFN", "CLF", "CLP",
    "CN1", "CNB", "CNF", "CUB", "CUM", "CUN", "CUO", "F3S", "FES", "FS2",
    "FS3", "FS4", "FSO", "FSX", "PHO", "BH1", "CHL", "CL1", "CL2", "CLA",
    "CCH", "CFO", "FE2", "FCI", "FCO", "FDC", "FEA", "FEO", "FNE", "HIF",
    "OFO", "PFC", "HE5", "BAZ", "BOZ", "FE", "HEM", "HCO", "1CP", "CLN",
    "COH", "CP3", "DEU", "FDD", "FDE", "FEC", "FMI", "HE5", "HEG", "HIF",
    "HNI", "MMP", "MNH", "MNR", "MP1", "PC3", "PCU", "PNI", "POR", "PP9",
    "MSE", "HIE", "HID", "HIP", "ACE", "FAD", "OEH", "NME", "PTH", "NDP",
    "NAD", "004", "00B", "00C", "00E", "00O", "01N", "01W", "02A", "02I", "02K", "02L", "02O", "02V", "02Y", "037", "03E", "03Y", "04R", "04U", "04V", "04X", "05N", "060", "07O", "08M", "08P", "0A", "0A0", "0A1", "0A2", "0A8", "0A9", "0AA", "0AB", "0AC", "0AD", "0AF", "0AH", "0AK", "0AM", "0AP", "0AR", "0AU", "0AV", "0AZ", "0BN", "0C", "0CS", "0DA", "0DC", "0DG", "0DT", "0E5", "0EA", "0EH", "0FL", "0G", "0G5", "0GG", "0KZ", "0LF", "0QL", "0QZ", "0R8", "0RJ", "0SP", "0TD", "0TH", "0TS", "0U", "0U1", "0UH", "0UZ", "0W6", "0WZ", "0X9", "0XL", "0XO", "0XQ", "0Y8", "0Y9", "10C", "11Q", "11W", "125", "126", "127", "128", "12A", "12L", "12X", "12Y", "13E", "143", "175", "18M", "18Q", "192", "193", "19W", "1AC", "1AP", "1C3", "1CC", "1DP", "1E3", "1FC", "1G2", "1G3", "1G8", "1JM", "1L1", "1MA", "1ME", "1MG", "1MH", "1OP", "1PA", "1PI", "1PR", "1RN", "1SC", "1TL", "1TQ", "1TW", "1TX", "1TY", "1U8", "1VR", "1W5", "1WA", "1X6", "1XW", "200", "22G", "23F", "23P", "23S", "28J", "28X", "2AD", "2AG", "2AO", "2AR", "2AS", "2AT", "2AU", "2BD", "2BT", "2BU", "2CO", "2DA", "2DF", "2DM", "2DO", "2DT", "2EG", "2FE", "2FI", "2FM", "2GF", "2GT", "2HF", "2IA", "2JC", "2JF", "2JG", "2JH", "2JJ", "2JN", "2JU", "2JV", "2KK", "2KP", "2KZ", "2L5", "2L6", "2L8", "2L9", "2LA", "2LF", "2LT", "2LU", "2MA", "2MG", "2ML", "2MR", "2MT", "2MU", "2NT", "2OM", "2OR", "2OT", "2P0", "2PI", "2PR", "2QD", "2QY", "2QZ", "2R1", "2R3", "2RA", "2RX", "2SA", "2SG", "2SI", "2SO", "2ST", "2TL", "2TY", "2VA", "2XA", "2YC", "2YF", "2YG", "2YH", "2YJ", "2ZC", "30F", "30V", "31H", "31M", "31Q", "32L", "32S", "32T", "33S", "33W", "33X", "34E", "35Y", "3A5", "3AH", "3AR", "3AU", "3BY", "3CF", "3CT", "3DA", "3DR", "3EG", "3FG", "3GA", "3GL", "3K4", "3MD", "3ME", "3MU", "3MY", "3NF", "3O3", "3PM", "3PX", "3QN", "3TD", "3TY", "3WS", "3X9", "3XH", "3YM", "3ZH", "3ZL", "3ZO", "41H", "41Q", "432", "45W", "47C", "4AC", "4AF", "4AK", "4AR", "4AW", "4BF", "4CF", "4CG", "4CY", "4D4", "4DB", "4DP", "4DU", "4F3", "4FB", "4FW", "4GC", "4GJ", "4HH", "4HJ", "4HL", "4HT", "4IK", "4IN", "4J2", "4KY", "4L0", "4L8", "4LZ", "4M8", "4MF", "4NT", "4NU", "4OC", "4OP", "4OU", "4OV", "4PC", "4PD", "4PE", "4PH", "4SC", "4SU", "4TA", "4U3", "4U7", "4WQ", "50L", "50N", "56A", "574", "5A6", "5AA", "5AB", "5AT", "5BU", "5CF", "5CG", "5CM", "5CS", "5CW", "5DW", "5FA", "5FC", "5FQ", "5FU", "5GG", "5HC", "5HM", "5HP", "5HT", "5HU", "5IC", "5IT", "5IU", "5JO", "5MC", "5MD", "5MU", "5NC", "5OC", "5OH", "5PC", "5PG", "5PY", "5R5", "5SE", "5UA", "5X8", "5XU", "5ZA", "62H", "63G", "63H", "64T", "68Z", "6CL", "6CT", "6CW", "6E4", "6FC", "6FL", "6FU", "6GL", "6HA", "6HB", "6HC", "6HG", "6HN", "6HT", "6IA", "6MA", "6MC", "6MI", "6MT", "6MZ", "6OG", "6PO", "70U", "7AT", "7BG", "7DA", "7GU", "7HA", "7JA", "7MG", "7MN", "81R", "81S", "823", "8AG", "8AN", "8AZ", "8FG", "8MG", "8OG", "8SP", "999", "9AT", "9DN", "9DS", "9NE", "9NF", "9NR", "9NV", "A", "A1P", "A23", "A2L", "A2M", "A34", "A35", "A38", "A39", "A3A", "A3P", "A40", "A43", "A44", "A47", "A5L", "A5M", "A5N", "A5O", "A66", "A6A", "A6C", "A6G", "A6U", "A7E", "A8E", "A9D", "A9Z", "AA3", "AA4", "AA6", "AAB", "AAR", "AB7", "ABA", "ABR", "ABS", "ABT", "AC5", "ACA", "ACB", "ACL", "AD2", "ADD", "ADX", "AE5", "AEA", "AEI", "AET", "AF2", "AFA", "AFF", "AFG", "AGD", "AGM", "AGQ", "AGT", "AHB", "AHH", "AHO", "AHP", "AIB", "AJE", "AKL", "ALA", "ALC", "ALM", "ALN", "ALO", "ALS", "ALT", "ALY", "AN6", "AN8", "AP7", "APH", "API", "APK", "APM", "APO", "APP", "AR2", "AR4", "ARG", "ARM", "ARO", "ARV", "AS", "AS2", "AS7", "AS9", "ASA", "ASB", "ASI", "ASK", "ASL", "ASM", "ASN", "ASP", "ASQ", "ASU", "ASX", "ATD", "ATL", "ATM", "AVC", "AVN", "AYA", "AYG", "AZH", "AZK", "AZS", "AZY", "B1F", "B1P", "B2N", "B3A", "B3E", "B3K", "B3L", "B3M", "B3Q", "B3S", "B3T", "B3U", "B3X", "B3Y", "B7C", "BB6", "BB7", "BB8", "BB9", "BBC", "BCS", "BCX", "BE2", "BFD", "BG1", "BGM", "BH2", "BHD", "BIF", "BIL", "BIU", "BJH", "BL2", "BMN", "BMP", "BMQ", "BMT", "BNN", "BOE", "BP5", "BPE", "BRU", "BSE", "BT5", "BTA", "BTC", "BTK", "BTR", "BUC", "BUG", "BYR", "BZG", "C", "C12", "C1T", "C1X", "C22", "C25", "C2L", "C2N", "C2S", "C31", "C32", "C34", "C36", "C37", "C38", "C3Y", "C42", "C43", "C45", "C46", "C49", "C4R", "C4S", "C5C", "C5L", "C66", "C6C", "C6G", "C99", "CAB", "CAF", "CAR", "CAS", "CAY", "CB2", "CBR", "CBV", "CCC", "CCL", "CCS", "CCY", "CDE", "CDV", "CDW", "CEA", "CFL", "CFY", "CFZ", "CG1", "CGA", "CGH", "CGU", "CGV", "CH", "CH6", "CH7", "CHG", "CHP", "CIR", "CJO", "CLB", "CLD", "CLE", "CLG", "CLH", "CLV", "CM0", "CME", "CMH", "CML", "CMR", "CMT", "CNG", "CNU", "CP1", "CPC", "CPI", "CQ1", "CQ2", "CQR", "CR0", "CR2", "CR5", "CR7", "CR8", "CRF", "CRG", "CRK", "CRO", "CRQ", "CRU", "CRW", "CRX", "CS0", "CS1", "CS3", "CS4", "CS8", "CSA", "CSB", "CSD", "CSE", "CSF", "CSH", "CSJ", "CSK", "CSL", "CSM", "CSO", "CSP", "CSR", "CSS", "CSU", "CSW", "CSX", "CSY", "CSZ", "CTE", "CTG", "CTH", "CTT", "CUC", "CUD", "CVC", "CWD", "CWR", "CX2", "CXM", "CY0", "CY1", "CY3", "CY4", "CYA", "CYF", "CYG", "CYJ", "CYM", "CYQ", "CYR", "CYS", "CYW", "CZ2", "CZO", "CZZ", "D00", "D11", "D1P", "D2T", "D3", "D33", "D3N", "D3P", "D4M", "D4P", "DA", "DA2", "DAB", "DAH", "DAL", "DAM", "DAR", "DAS", "DBB", "DBM", "DBS", "DBU", "DBY", "DBZ", "DC", "DC2", "DCG", "DCT", "DCY", "DDE", "DDG", "DDN", "DDX", "DDZ", "DFC", "DFF", "DFG", "DFI", "DFO", "DFT", "DG", "DG8", "DGH", "DGI", "DGL", "DGN", "DGP", "DHA", "DHI", "DHL", "DHN", "DHP", "DHU", "DHV", "DI", "DI7", "DI8", "DIL", "DIR", "DIV", "DJF", "DLE", "DLS", "DLY", "DM0", "DMH", "DMK", "DMT", "DN", "DNE", "DNG", "DNL", "DNP", "DNR", "DNS", "DNW", "DO2", "DOA", "DOC", "DOH", "DON", "DPB", "DPL", "DPN", "DPP", "DPQ", "DPR", "DPY", "DRM", "DRP", "DRT", "DRZ", "DSE", "DSG", "DSN", "DSP", "DT", "DTH", "DTR", "DTY", "DU", "DUZ", "DVA", "DXD", "DXN", "DYA", "DYG", "DYL", "DYS", "DZM", "E", "E1X", "ECC", "ECX", "EDA", "EDC", "EDI", "EFC", "EHG", "EHP", "EIT", "ELY", "EME", "ENA", "ENP", "ENQ", "ESB", "ESC", "EXC", "EXY", "EYG", "EYS", "F2F", "F2Y", "F3H", "F3M", "F3N", "F3O", "F3T", "F4H", "F5H", "F6H", "FA2", "FA5", "FAG", "FAI", "FAK", "FAX", "FB5", "FB6", "FCL", "FDG", "FDL", "FFD", "FFM", "FGA", "FGL", "FGP", "FH7", "FHL", "FHO", "FHU", "FIO", "FLA", "FLE", "FLT", "FME", "FMG", "FMU", "FNU", "FOE", "FOX", "FP9", "FPK", "FPR", "FRD", "FT6", "FTR", "FTY", "FVA", "FZN", "G", "G25", "G2L", "G2S", "G31", "G32", "G33", "G35", "G36", "G38", "G42", "G46", "G47", "G48", "G49", "G4P", "G7M", "G8M", "GAO", "GAU", "GCK", "GCM", "GDO", "GDP", "GDR", "GEE", "GF2", "GFL", "GFT", "GGL", "GH3", "GHC", "GHG", "GHP", "GHW", "GL3", "GLH", "GLJ", "GLM", "GLN", "GLQ", "GLU", "GLX", "GLY", "GLZ", "GMA", "GME", "GMS", "GMU", "GN7", "GNC", "GND", "GNE", "GOM", "GPL", "GRB", "GS", "GSC", "GSR", "GSS", "GSU", "GT9", "GU0", "GU1", "GU2", "GU4", "GU5", "GU8", "GU9", "GVL", "GX1", "GYC", "GYS", "H14", "H2U", "H5M", "HAC", "HAR", "HBN", "HCL", "HCM", "HCS", "HDP", "HEU", "HFA", "HG7", "HGL", "HGM", "HGY", "HHI", "HHK", "HIA", "HIC", "HIP", "HIQ", "HIS", "HIX", "HL2", "HLU", "HLX", "HM8", "HM9", "HMF", "HMR", "HN0", "HN1", "HNC", "HOL", "HOX", "HPC", "HPE", "HPQ", "HQA", "HR7", "HRG", "HRP", "HS8", "HS9", "HSE", "HSK", "HSL", "HSO", "HSV", "HT7", "HTI", "HTN", "HTR", "HTY", "HV5", "HVA", "HY3", "HYP", "HZP", "I", "I2M", "I4G", "I58", "I5C", "IAM", "IAR", "IAS", "IC", "ICY", "IEL", "IEY", "IG", "IGL", "IGU", "IIC", "IIL", "ILE", "ILG", "ILX", "IMC", "IML", "IOR", "IOY", "IPG", "IPN", "IRN", "IT1", "IU", "IYR", "IYT", "IZO", "JDT", "JJJ", "JJK", "JJL", "JLN", "JW5", "K1R", "KAG", "KBE", "KCR", "KCX", "KCY", "KFP", "KGC", "KNB", "KOR", "KPF", "KPI", "KPY", "KST", "KWS", "KYN", "KYQ", "L2A", "L3O", "L5P", "LA2", "LAA", "LAG", "LAL", "LAY", "LBY", "LC", "LCA", "LCC", "LCG", "LCH", "LCK", "LCX", "LDH", "LE1", "LED", "LEF", "LEH", "LEI", "LEM", "LET", "LEU", "LG", "LGP", "LGY", "LHC", "LHO", "LHU", "LKC", "LLO", "LLP", "LLY", "LLZ", "LM2", "LME", "LMF", "LMQ", "LMS", "LNE", "LNM", "LP6", "LPD", "LPG", "LPH", "LPL", "LPS", "LRK", "LSO", "LTA", "LTP", "LTR", "LVG", "LVN", "LWM", "LYF", "LYH", "LYM", "LYN", "LYO", "LYR", "LYS", "LYU", "LYV", "LYX", "LYZ", "M0H", "M1G", "M2G", "M2L", "M2S", "M30", "M3L", "M3O", "M4C", "M5M", "MA6", "MA7", "MAA", "MAD", "MAI", "MBQ", "MBZ", "MC1", "MCG", "MCL", "MCS", "MCY", "MD0", "MD3", "MD5", "MD6", "MDF", "MDH", "MDJ", "MDK", "MDO", "MDQ", "MDR", "MDU", "MDV", "ME0", "ME6", "MEA", "MED", "MEG", "MEN", "MEP", "MEQ", "MET", "MEU", "MF3", "MF7", "MFC", "MFT", "MG1", "MGG", "MGN", "MGQ", "MGV", "MGY", "MH1", "MH6", "MH8", "MHL", "MHO", "MHS", "MHU", "MHV", "MHW", "MIA", "MIR", "MIS", "MK8", "MKD", "ML3", "MLE", "MLL", "MLU", "MLY", "MLZ", "MM7", "MME", "MMO", "MMT", "MND", "MNL", "MNU", "MNV", "MOD", "MOZ", "MP4", "MP8", "MPH", "MPJ", "MPQ", "MRG", "MSA", "MSE", "MSL", "MSO", "MSP", "MT2", "MTR", "MTU", "MTY", "MV9", "MVA", "MYK", "MYN", "N", "N10", "N2C", "N4S", "N5I", "N5M", "N6G", "N7P", "N80", "N8P", "NA8", "NAL", "NAM", "NB8", "NBQ", "NC1", "NCB", "NCU", "NCX", "NCY", "NDF", "NDN", "NDU", "NEM", "NEP", "NF2", "NFA", "NHL", "NIY", "NKS", "NLB", "NLE", "NLN", "NLO", "NLP", "NLQ", "NLY", "NMC", "NMM", "NMS", "NMT", "NNH", "NOT", "NP3", "NPH", "NPI", "NR1", "NRG", "NRI", "NRP", "NRQ", "NSK", "NTR", "NTT", "NTY", "NVA", "NWD", "NYB", "NYC", "NYG", "NYM", "NYS", "NZC", "NZH", "O12", "O2C", "O2G", "OAD", "OAS", "OBF", "OBS", "OCS", "OCY", "ODP", "OEM", "OFM", "OGX", "OHI", "OHS", "OHU", "OIC", "OIM", "OIP", "OLD", "OLE", "OLT", "OLZ", "OMC", "OMG", "OMH", "OMT", "OMU", "OMX", "OMY", "OMZ", "ONE", "ONH", "ONL", "ORD", "ORN", "ORQ", "OSE", "OTB", "OTH", "OTY", "OXX", "OYL", "P", "P0A", "P1L", "P1P", "P2Q", "P2T", "P2U", "P2Y", "P3Q", "P4E", "P4F", "P5P", "P9G", "PAQ", "PAS", "PAT", "PBB", "PBF", "PBT", "PCA", "PCC", "PCE", "PCS", "PDD", "PDL", "PDU", "PDW", "PE1", "PEC", "PF5", "PFF", "PG1", "PG7", "PG9", "PGN", "PGP", "PGY", "PH6", "PH8", "PHA", "PHD", "PHE", "PHI", "PHL", "PIA", "PIV", "PLJ", "PM3", "PMT", "POM", "PPN", "PPU", "PPW", "PQ1", "PR3", "PR4", "PR5", "PR7", "PR9", "PRJ", "PRK", "PRN", "PRO", "PRQ", "PRR", "PRS", "PRV", "PSH", "PST", "PSU", "PSW", "PTH", "PTM", "PTR", "PU", "PUY", "PVH", "PVL", "PVX", "PXU", "PYA", "PYH", "PYL", "PYO", "PYX", "PYY", "QAC", "QBT", "QCS", "QDS", "QFG", "QIL", "QLG", "QMM", "QPA", "QPH", "QUO", "QV4", "R", "R1A", "R2P", "R2T", "R4K", "RBD", "RC7", "RCE", "RDG", "RE0", "RE3", "RGL", "RIA", "RMP", "RON", "RPC", "RSP", "RSQ", "RT", "RT0", "RTP", "RUS", "RVX", "RZ4", "S12", "S1H", "S2C", "S2D", "S2M", "S2P", "S4A", "S4C", "S4G", "S4U", "S6G", "S8M", "SAC", "SAH", "SAR", "SAY", "SBD", "SBL", "SC", "SCH", "SCS", "SCY", "SD2", "SD4", "SDE", "SDG", "SDH", "SDP", "SE7", "SEB", "SEC", "SEE", "SEG", "SEL", "SEM", "SEN", "SEP", "SER", "SET", "SFE", "SGB", "SHC", "SHP", "SHR", "SIB", "SIC", "SLL", "SLR", "SLZ", "SMC", "SME", "SMF", "SMP", "SMT", "SNC", "SNN", "SOC", "SOS", "SOY", "SPT", "SRA", "SRZ", "SSU", "STY", "SUB", "SUI", "SUN", "SUR", "SUS", "SVA", "SVV", "SVW", "SVX", "SVY", "SVZ", "SWG", "SXE", "SYS", "T", "T0I", "T0T", "T11", "T23", "T2S", "T2T", "T31", "T32", "T36", "T37", "T38", "T39", "T3P", "T41", "T48", "T49", "T4S", "T5O", "T5S", "T64", "T66", "T6A", "TA3", "TA4", "TAF", "TAL", "TAV", "TBG", "TBM", "TC1", "TCP", "TCQ", "TCR", "TCY", "TDD", "TDF", "TDY", "TED", "TEF", "TFE", "TFF", "TFO", "TFQ", "TFR", "TFT", "TGP", "TH5", "TH6", "THC", "THO", "THP", "THR", "THX", "THZ", "TIH", "TIS", "TLB", "TLC", "TLN", "TLY", "TMB", "TMD", "TNB", "TNR", "TNY", "TOQ", "TOX", "TP1", "TPC", "TPG", "TPH", "TPJ", "TPK", "TPL", "TPO", "TPQ", "TQI", "TQQ", "TQZ", "TRF", "TRG", "TRN", "TRO", "TRP", "TRQ", "TRW", "TRX", "TRY", "TS", "TS9", "TST", "TSY", "TT", "TTD", "TTI", "TTM", "TTQ", "TTS", "TX2", "TXY", "TY1", "TY2", "TY3", "TY5", "TY8", "TY9", "TYB", "TYI", "TYJ", "TYN", "TYO", "TYQ", "TYR", "TYS", "TYT", "TYU", "TYX", "TYY", "TZB", "TZO", "U", "U25", "U2L", "U2N", "U2P", "U2X", "U31", "U33", "U34", "U36", "U37", "U3X", "U8U", "UAL", "UAR", "UBD", "UBI", "UBR", "UCL", "UD5", "UDP", "UDS", "UF0", "UF2", "UFP", "UFR", "UFT", "UGY", "UM1", "UM2", "UMA", "UMS", "UMX", "UN1", "UN2", "UNK", "UOX", "UPE", "UPS", "UPV", "UR3", "URD", "URU", "URX", "US1", "US2", "US3", "US4", "US5", "USM", "UU4", "UU5", "UVX", "V3L", "VAD", "VAF", "VAH", "VAL", "VB1", "VDL", "VET", "VH0", "VLL", "VLM", "VMS", "VOL", "VR0", "WCR", "WFP", "WLU", "WPA", "WRP", "WVL", "X", "X2W", "X4A", "X9Q", "XAD", "XAE", "XAL", "XAR", "XCL", "XCN", "XCR", "XCS", "XCT", "XCY", "XDT", "XGA", "XGL", "XGR", "XGU", "XPB", "XPL", "XPR", "XSN", "XTF", "XTH", "XTL", "XTR", "XTS", "XTY", "XUA", "XUG", "XW1", "XX1", "XXA", "XXY", "XYG", "Y", "Y28", "Y5P", "YCM", "YCO", "YCP", "YG", "YNM", "YOF", "YPR", "YPZ", "YRR", "YTH", "YYA", "YYG", "Z", "Z01", "Z3E", "Z70", "ZAD", "ZAE", "ZAL", "ZBC", "ZBU", "ZBZ", "ZCL", "ZCY", "ZDU", "ZFB", "ZGL", "ZGU", "ZHP", "ZTH", "ZU0", "ZUK", "ZYJ", "ZYK", "ZZD", "ZZJ", "ZZU"};

static const int ST_nb_keep_hetatm = 1961; // 121

static molfile_plugin_t *api;

static int register_cb(void *v, vmdplugin_t *p)
{
    api = (molfile_plugin_t *)p;
    return 0;
}

s_pdb *open_mmcif(char *fpath, const char *ligan, const int keep_lig, int model_number, s_fparams *par)
{
    /*COPY FROM rpdb_open of rpdb.c*/
    s_pdb *pdb = NULL;

    char buf[M_PDB_BUF_LEN],
        resb[5]; //, chainb[5];

    int nhetatm = 0,
        natoms = 0,
        natm_lig = 0;
    int i;

    int resnbuf = 0;
    int model_flag = 0;      /*by default we consider that no particular model is read*/
    int model_read = 0;      /*flag tracking the status if a current line is read or not*/
    int cur_model_count = 0; /*when reading NMR models, then count on which model you currently are*/
    pdb = (s_pdb *)my_malloc(sizeof(s_pdb));
    ;
    pdb->n_xlig_atoms = 0;
    pdb->xlig_x = NULL;
    pdb->xlig_y = NULL;
    pdb->xlig_z = NULL;

    pdb->fpdb = fopen_pdb_check_case(fpath, "r"); /*just so free pdb doesnt crash*/

    /***************************************************************/

    molfile_pdbxplugin_init();
    molfile_pdbxplugin_register(NULL, register_cb);
    char *filetype = "cif";
    int inatoms; /*number of atoms in the  file determined by molfile api*/
    // printf("%s | %s |%d", fpath, filetype, inatoms);
    // printf("\n");
    void *h_in;
    molfile_timestep_t ts_in;
    molfile_atom_t *at_in;
    int optflags = 0x0040;
    int rc;
    int rc2;
    int j;
    int k;

    h_in = api->open_file_read(fpath, filetype, &inatoms);
    at_in = (molfile_atom_t *)malloc(inatoms * sizeof(molfile_atom_t));
    ts_in.coords = (float *)malloc(3 * inatoms * sizeof(float)); /*allocating space for the coords*/
    rc2 = api->read_structure(h_in, &optflags, at_in);
    rc = api->read_next_timestep(h_in, inatoms, &ts_in);
    if (!model_number)
        model_number = 1;
    model_flag = 1;
    for (i = 0; i < inatoms; i++) /*loop to go through all atoms*/
    {
        if (at_in[i].altloc[0] == '.' || at_in[i].altloc[0] == '\0')
            at_in[i].altloc[0] = ' ';
        if (at_in[i].modelnumber == model_number && !strncmp(at_in[i].atom_type, "ATOM", 4) && !is_ligand(par->chain_as_ligand, at_in[i].chain[0]))
        {
            if (at_in[i].altloc[0] == ' ' || at_in[i].altloc[0] == 'A' || at_in[i].altloc[0] == '?')

            {
                if (chains_to_delete(par->chain_delete, at_in[i].chain[0], par->chain_is_kept))
                {
                    /* Atom entry: check if there is a ligand in there (just in case)... */
                    if (ligan && strlen(ligan) > 1 && ligan[0] == at_in[i].resname[0] && ligan[1] == at_in[i].resname[1] && ligan[2] == at_in[i].resname[2])
                    {
                        if (keep_lig)
                        {
                            natm_lig++;
                            natoms++;
                        }
                        /*check this function*/
                    }
                    else if (ligan && strlen(ligan) == 1 && at_in[i].chain[0] == ligan[0])
                    { /*here we have a protein chain defined as ligand...a bit more complex then*/
                        if (keep_lig)
                        {
                            natm_lig++;
                            natoms++;
                        }
                    }
                    else
                    {
                        natoms++;
                    }
                }
                if (par->xlig_resnumber > -1)
                {

                    // if ((at_in[i].chain[0] == par->xlig_chain_code[0] && at_in[i].resid == par->xlig_resnumber && par->xlig_resname[0] == at_in[i].resname[0] && par->xlig_resname[1] == at_in[i].resname[1] && par->xlig_resname[2] == at_in[i].resname[2]) || (at_in[i].chain_auth[0] == par->xlig_chain_code[0] && at_in[i].resid_auth == par->xlig_resnumber && par->xlig_resname[0] == at_in[i].resname[0] && par->xlig_resname[1] == at_in[i].resname[1] && par->xlig_resname[2] == at_in[i].resname[2]))
                    // {
                    //     pdb->n_xlig_atoms++;
                    // }

                    if (is_ligand(par->chain_as_ligand, at_in[i].chain[0]))
                    {
                        pdb->n_xlig_atoms++;
                    }
                }
            }
            if (par->xlig_resnumber > -1)
            {

                if ((at_in[i].chain[0] == par->xlig_chain_code[0] && at_in[i].resid == par->xlig_resnumber && par->xlig_resname[0] == at_in[i].resname[0] && par->xlig_resname[1] == at_in[i].resname[1] && par->xlig_resname[2] == at_in[i].resname[2]) || (at_in[i].chain_auth[0] == par->xlig_chain_code[0] && at_in[i].resid_auth == par->xlig_resnumber && par->xlig_resname[0] == at_in[i].resname[0] && par->xlig_resname[1] == at_in[i].resname[1] && par->xlig_resname[2] == at_in[i].resname[2]))
                {
                    pdb->n_xlig_atoms++;
                }
            }
        }
        else if (at_in[i].modelnumber == model_number && !strncmp(at_in[i].atom_type, "HETATM", 6) || (!strncmp(at_in[i].atom_type, "ATOM", 4) && is_ligand(par->chain_as_ligand, at_in[i].chain[0])))
        {

            if (at_in[i].altloc[0] == '?' || at_in[i].altloc[0] == ' ' || at_in[i].altloc[0] == 'A' || at_in[i].altloc[0] == '1')
            {

                if (chains_to_delete(par->chain_delete, at_in[i].chain[0], par->chain_is_kept))
                {
                    if (ligan && strlen(ligan) > 1 && keep_lig && ligan[0] == at_in[i].resname[0] && ligan[1] == at_in[i].resname[1] && ligan[2] == at_in[i].resname[2])
                    {
                        natm_lig++;
                        natoms++;
                    }
                    else if (ligan && strlen(ligan) == 1 && ligan[0] == at_in[i].chain[0])
                    {
                        if (keep_lig)
                            natm_lig++;
                        natoms++;
                    }
                    else
                    {
                        /* Keep specific HETATM given in the static list ST_keep_hetatm */
                        if ((keep_lig && !ligan && strncmp(at_in[i].resname, "HOH", 3) && strncmp(at_in[i].resname, "WAT", 3) && strncmp(at_in[i].resname, "TIP", 3)) || (keep_lig && is_ligand(par->chain_as_ligand, at_in[i].chain[0])))
                        {

                            natoms++;
                            nhetatm++;
                        }
                        else if (!is_ligand(par->chain_as_ligand, at_in[i].chain[0]))
                        {
                            for (j = 0; j < ST_nb_keep_hetatm; j++)
                            {
                                if (ST_keep_hetatm[j][0] == at_in[i].resname[0] && ST_keep_hetatm[j][1] == at_in[i].resname[1] && ST_keep_hetatm[j][2] == at_in[i].resname[2])
                                {
                                    nhetatm++;
                                    natoms++;
                                    break;
                                }
                            }
                        }
                    }
                }

                if (is_ligand(par->chain_as_ligand, at_in[i].chain[0]))
                {
                    pdb->n_xlig_atoms++;
                }
            }
            if (par->xlig_resnumber > -1)
            {
                if ((at_in[i].chain[0] == par->xlig_chain_code[0] && at_in[i].resid == par->xlig_resnumber && par->xlig_resname[0] == at_in[i].resname[0] && par->xlig_resname[1] == at_in[i].resname[1] && par->xlig_resname[2] == at_in[i].resname[2]) || (at_in[i].chain_auth[0] == par->xlig_chain_code[0] && at_in[i].resid_auth == par->xlig_resnumber && par->xlig_resname[0] == at_in[i].resname[0] && par->xlig_resname[1] == at_in[i].resname[1] && par->xlig_resname[2] == at_in[i].resname[2]))
                {
                    pdb->n_xlig_atoms++;
                }
            }
        }
    }

    if (pdb->n_xlig_atoms)
    {
        pdb->xlig_x = (float *)my_malloc(sizeof(float) * pdb->n_xlig_atoms);
        pdb->xlig_y = (float *)my_malloc(sizeof(float) * pdb->n_xlig_atoms);
        pdb->xlig_z = (float *)my_malloc(sizeof(float) * pdb->n_xlig_atoms);
    }

    if (natoms == 0)
    {
        fprintf(stderr, "! File '%s' contains no atoms...\n", fpath);
        my_free(pdb);

        return NULL;
    }

    /* Alloc needed memory */
    pdb->latoms = (s_atm *)my_calloc(natoms, sizeof(s_atm));
    pdb->latoms_p = (s_atm **)my_calloc(natoms, sizeof(s_atm *));

    if (nhetatm > 0)
        pdb->lhetatm = (s_atm **)my_calloc(nhetatm, sizeof(s_atm *));
    else
        pdb->lhetatm = NULL;

    if (natm_lig > 0)
        pdb->latm_lig = (s_atm **)my_calloc(natm_lig, sizeof(s_atm *));
    else
        pdb->latm_lig = NULL;

    pdb->natoms = natoms;
    pdb->nhetatm = nhetatm;
    pdb->natm_lig = natm_lig;
    strcpy(pdb->fname, fpath);

    api->close_file_read(h_in);
    return pdb;
}

void read_mmcif(s_pdb *pdb, const char *ligan, const int keep_lig, int model_number, s_fparams *params)
{
    int i,
        iatoms,
        ihetatm,
        iatm_lig,
        ligfound;

    char pdb_line[M_PDB_BUF_LEN],
        resb[5];             /* Buffer for the current residue name */
                             // fprintf("%c",resb);
    int model_flag = 0;      /*by default we consider that no particular model is read*/
    int model_read = 0;      /*flag tracking the status if a current line is read or not*/
    int cur_model_count = 0; /*when reading NMR models, then count on which model you currently are*/
    s_atm *atom = NULL;
    s_atm *atoms = pdb->latoms;
    s_atm **atoms_p = pdb->latoms_p;
    s_atm **atm_lig = pdb->latm_lig;
    int guess_flag = 0;
    iatoms = 0;
    int i_explicit_ligand_atom = 0; // counter to know on which atom of the ligand we are to define an explicit pocket
    ihetatm = 0;
    iatm_lig = 0;
    ligfound = 0;
    int resnbuf = 0;

    /*******************************************************************************/
    molfile_pdbxplugin_init();
    molfile_pdbxplugin_register(NULL, register_cb);
    char *filetype = "cif";
    int inatoms; /*number of atoms in the  file determined by molfile api*/

    void *h_in;
    molfile_timestep_t ts_in;
    molfile_atom_t *at_in;
    int optflags = 0x0040;
    int rc;
    int rc2;
    int j;
    int k;

    h_in = api->open_file_read(pdb->fname, filetype, &inatoms);
    at_in = (molfile_atom_t *)malloc(inatoms * sizeof(molfile_atom_t));
    ts_in.coords = (float *)malloc(3 * inatoms * sizeof(float)); /*allocating space for the coords*/
    rc2 = api->read_structure(h_in, &optflags, at_in);
    rc = api->read_next_timestep(h_in, inatoms, &ts_in);
    // printf("READ : %s | %s |%d\n", pdb->fname, filetype, inatoms);
    /* Loop over the pdb file */
    model_flag = 1;
    if (!model_number)
        model_number = 1;
    ; /*here we indicate that a particular model should be read only*/
    for (i = 0; i < inatoms; i++)
    {
        if (at_in[i].altloc[0] == '.' || at_in[i].altloc[0] == '\0')
            at_in[i].altloc[0] = ' ';

        if (at_in[i].modelnumber == model_number && !strncmp(at_in[i].atom_type, "ATOM", 4) && !is_ligand(params->chain_as_ligand, at_in[i].chain[0]))
        {

            if (at_in[i].altloc[0] == ' ' || at_in[i].altloc[0] == 'A' || at_in[i].altloc[0] == '1' || at_in[i].altloc[0] == '?')
            { /*if within first occurence*/
                /* Enter this if when arg in command line is -r */

                /* Enter this if when arg in command line is -a */
                if (is_ligand(params->chain_as_ligand, at_in[i].chain[0]))
                {
                    *(pdb->xlig_x + i_explicit_ligand_atom) = ts_in.coords[3 * i];
                    *(pdb->xlig_y + i_explicit_ligand_atom) = ts_in.coords[(3 * i) + 1];
                    *(pdb->xlig_z + i_explicit_ligand_atom) = ts_in.coords[(3 * i) + 2];
                    i_explicit_ligand_atom++;
                }
                if (chains_to_delete(params->chain_delete, at_in[i].chain[0], params->chain_is_kept)) // deleting the chains we want to delete from pdb file
                {
                    /* Check if the desired ligand is in such an entry */
                    if (ligan && strlen(ligan) > 1 && ligan[0] == at_in[i].resname[0] && ligan[1] == at_in[i].resname[1] && ligan[2] == at_in[i].resname[2])
                    {
                        if (keep_lig)
                        {
                            atom = atoms + iatoms;

                            strcpy(atom->type, at_in[i].atom_type);
                            atom->id = i + 1;
                            strcpy(atom->name, at_in[i].type);
                            atom->pdb_aloc = at_in[i].altloc[0];
                            strcpy(atom->res_name, at_in[i].resname);
                            strncpy(atom->chain, at_in[i].chain, 2);
                            atom->res_id = at_in[i].resid;
                            atom->pdb_insert = at_in[i].insertion[0];
                            atom->x = ts_in.coords[(3 * i)];
                            atom->y = ts_in.coords[(3 * i) + 1];
                            atom->z = ts_in.coords[(3 * i) + 2];
                            atom->occupancy = at_in[i].occupancy;
                            atom->bfactor = at_in[i].bfactor;
                            strncpy(atom->symbol, pte_get_element_from_number(at_in[i].atomicnumber), 3);

                            atom->charge = at_in[i].charge;
                            atom->mass = at_in[i].mass;
                            atom->radius = at_in[i].radius;
                            atom->electroneg = pte_get_enegativity(atom->symbol);
                            guess_flag += 1;
                            atom->sort_x = -1;

                            atoms_p[iatoms] = atom;
                            iatoms++;

                            atm_lig[iatm_lig] = atom;
                            iatm_lig++;
                            ligfound = 1;
                        }
                    }
                    else if (ligan && strlen(ligan) == 1 && at_in[i].chain[0] == ligan[0])
                    { /*here we have a protein chain defined as ligand...a bit more complex then*/
                        if (keep_lig)
                        {

                            atom = atoms + iatoms;

                            strcpy(atom->type, at_in[i].atom_type);
                            atom->id = i + 1;
                            strcpy(atom->name, at_in[i].type);
                            atom->pdb_aloc = at_in[i].altloc[0];
                            strcpy(atom->res_name, at_in[i].resname);
                            strncpy(atom->chain, at_in[i].chain, 2);
                            atom->res_id = at_in[i].resid;
                            // fprintf(stdout, " here : %c\n", at_in[i].insertion[0]);
                            atom->pdb_insert = at_in[i].insertion[0];
                            atom->x = ts_in.coords[(3 * i)];
                            atom->y = ts_in.coords[(3 * i) + 1];
                            atom->z = ts_in.coords[(3 * i) + 2];
                            atom->occupancy = at_in[i].occupancy;
                            atom->bfactor = at_in[i].bfactor;
                            strncpy(atom->symbol, pte_get_element_from_number(at_in[i].atomicnumber), 3);

                            atom->charge = at_in[i].charge;
                            atom->mass = at_in[i].mass;
                            atom->radius = at_in[i].radius;

                            atom->electroneg = pte_get_enegativity(atom->symbol);
                            guess_flag += 1;

                            /* Store additional information not given in the pdb
                            atom->mass = pte_get_mass(atom->symbol);
                            atom->radius = pte_get_vdw_ray(atom->symbol);
                            atom->electroneg = pte_get_enegativity(atom->symbol);*/

                            atom->sort_x = -1;

                            atoms_p[iatoms] = atom;
                            iatoms++;

                            atm_lig[iatm_lig] = atom;
                            iatm_lig++;
                            ligfound = 1;
                        }
                    }

                    else
                    {

                        /* A simple atom not supposed to be stored as a ligand */

                        atom = atoms + iatoms;
                        strcpy(atom->type, at_in[i].atom_type);
                        atom->id = i + 1;
                        strcpy(atom->name, at_in[i].type);
                        atom->pdb_aloc = at_in[i].altloc[0];
                        strcpy(atom->res_name, at_in[i].resname);
                        // fprintf(stdout,"%s |%s|%d\n", atom->chain, at_in[i].chain,i);
                        // fflush(stdout);
                        strncpy(atom->chain, at_in[i].chain, 2);
                        // fprintf(stdout,"%s |%s|%d\n", atom->chain, at_in[i].chain,i);
                        atom->res_id = at_in[i].resid;
                        atom->pdb_insert = at_in[i].insertion[0];
                        // printf("ins:%s",at_in[i].insertion);

                        atom->x = ts_in.coords[(3 * i)];
                        atom->y = ts_in.coords[(3 * i) + 1];
                        atom->z = ts_in.coords[(3 * i) + 2];
                        atom->occupancy = at_in[i].occupancy;
                        atom->bfactor = at_in[i].bfactor;
                        strncpy(atom->symbol, pte_get_element_from_number(at_in[i].atomicnumber), 3);

                        atom->charge = at_in[i].charge;
                        atom->mass = at_in[i].mass;
                        atom->radius = at_in[i].radius;

                        atom->electroneg = pte_get_enegativity_from_number(at_in[i].atomicnumber);
                        guess_flag += 1;

                        /* Store additional information not given in the pdb */

                        atom->sort_x = -1;
                        // printf("type : %s, id : %d, name : %s, aloc : %c, res_name : %s, chain  : %s, res_id : %d, pdb_insert : %c, occupancy : %f, b_factor : %f, symbol : %s, charge : %d\n",
                        //        atom->type, atom->id, atom->name, atom->pdb_aloc, atom->res_name, atom->chain, atom->res_id, atom->pdb_insert, atom->occupancy, atom->bfactor, atom->symbol, atom->charge);
                        // printf("electroneg : %s\n",atom->symbol);

                        atoms_p[iatoms] = atom;
                        iatoms++;
                    }
                }
            }
            if (pdb->n_xlig_atoms)
            {
                if (at_in[i].chain[0] == params->xlig_chain_code[0] && at_in[i].resid == params->xlig_resnumber && params->xlig_resname[0] == at_in[i].resname[0] && params->xlig_resname[1] == at_in[i].resname[1] && params->xlig_resname[2] == at_in[i].resname[2])
                {

                    *(pdb->xlig_x + i_explicit_ligand_atom) = ts_in.coords[3 * i];
                    *(pdb->xlig_y + i_explicit_ligand_atom) = ts_in.coords[(3 * i) + 1];
                    *(pdb->xlig_z + i_explicit_ligand_atom) = ts_in.coords[(3 * i) + 2];
                    i_explicit_ligand_atom++;
                }
            }
        }
        else if (at_in[i].modelnumber == model_number && !strncmp(at_in[i].atom_type, "HETATM", 6) || (!strncmp(at_in[i].atom_type, "ATOM", 4) && is_ligand(params->chain_as_ligand, at_in[i].chain[0])))
        {

            if (at_in[i].altloc[0] == ' ' || at_in[i].altloc[0] == 'A' || at_in[i].altloc[0] == '1' || at_in[i].altloc[0] =='?')
            { /*first occurence*/

                if (is_ligand(params->chain_as_ligand, at_in[i].chain[0]))
                {
                    *(pdb->xlig_x + i_explicit_ligand_atom) = ts_in.coords[3 * i];
                    *(pdb->xlig_y + i_explicit_ligand_atom) = ts_in.coords[(3 * i) + 1];
                    *(pdb->xlig_z + i_explicit_ligand_atom) = ts_in.coords[(3 * i) + 2];

                    // printf("%d\n", i_explicit_ligand_atom);
                    i_explicit_ligand_atom++;
                }
                // fflush(stdout);
                if (chains_to_delete(params->chain_delete, at_in[i].chain[0], params->chain_is_kept)) // deleting the chains we want to delete from pdb file
                {
                    /* Check if the desired ligand is in HETATM entry */
                    if (ligan && strlen(ligan) > 1 && keep_lig && ligan[0] == at_in[i].resname[0] && ligan[1] == at_in[i].resname[1] && ligan[2] == at_in[i].resname[2])
                    {
                        atom = atoms + iatoms;
                        strcpy(atom->type, at_in[i].atom_type);

                        atom->id = i + 1;
                        strcpy(atom->name, at_in[i].type);
                        atom->pdb_aloc = at_in[i].altloc[0];
                        strcpy(atom->res_name, at_in[i].resname);
                        strncpy(atom->chain, at_in[i].chain, 2);
                        atom->res_id = at_in[i].resid;
                        atom->pdb_insert = at_in[i].insertion[0];
                        atom->x = ts_in.coords[(3 * i)];
                        atom->y = ts_in.coords[(3 * i) + 1];
                        atom->z = ts_in.coords[(3 * i) + 2];
                        atom->occupancy = at_in[i].occupancy;
                        atom->bfactor = at_in[i].bfactor;
                        strncpy(atom->symbol, pte_get_element_from_number(at_in[i].atomicnumber), 3);

                        atom->charge = at_in[i].charge;
                        atom->mass = at_in[i].mass;
                        atom->radius = at_in[i].radius;
                        atom->electroneg = pte_get_enegativity(atom->symbol);
                        guess_flag += 1;
                        atom->sort_x = -1;

                        atoms_p[iatoms] = atom;
                        atm_lig[iatm_lig] = atom;

                        iatm_lig++;
                        iatoms++;
                        ligfound = 1;
                    }
                    else if (ligan && strlen(ligan) == 1 && ligan[0] == at_in[i].chain[0])
                    {

                        if (keep_lig)
                        {

                            atom = atoms + iatoms;
                            strcpy(atom->type, at_in[i].atom_type);

                            atom->id = i + 1;
                            strcpy(atom->name, at_in[i].type);
                            atom->pdb_aloc = at_in[i].altloc[0];
                            strcpy(atom->res_name, at_in[i].resname);
                            strncpy(atom->chain, at_in[i].chain, 2);
                            atom->res_id = at_in[i].resid;
                            atom->pdb_insert = at_in[i].insertion[0];
                            atom->x = ts_in.coords[(3 * i)];
                            atom->y = ts_in.coords[(3 * i) + 1];
                            atom->z = ts_in.coords[(3 * i) + 2];
                            atom->occupancy = at_in[i].occupancy;
                            atom->bfactor = at_in[i].bfactor;
                            strncpy(atom->symbol, pte_get_element_from_number(at_in[i].atomicnumber), 3);

                            atom->charge = at_in[i].charge;
                            atom->mass = at_in[i].mass;
                            atom->radius = at_in[i].radius;
                            atom->electroneg = pte_get_enegativity(atom->symbol);
                            guess_flag += 1;
                            atom->sort_x = -1;

                            atoms_p[iatoms] = atom;
                            atm_lig[iatm_lig] = atom;

                            iatm_lig++;
                            iatoms++;
                            ligfound = 1;
                        }
                    }
                    else if (pdb->lhetatm)
                    {

                        /* Keep specific HETATM given in the static list ST_keep_hetatm. */
                        if ((keep_lig && !ligan && strncmp(at_in[i].resname, "HOH", 3) && strncmp(at_in[i].resname, "WAT", 3) && strncmp(at_in[i].resname, "TIP", 3)) || (keep_lig && is_ligand(params->chain_as_ligand, at_in[i].chain[0])))
                        {

                            atom = atoms + iatoms;
                            strcpy(atom->type, at_in[i].atom_type);
                            atom->id = i + 1;
                            strcpy(atom->name, at_in[i].type);
                            atom->pdb_aloc = at_in[i].altloc[0];
                            strcpy(atom->res_name, at_in[i].resname);
                            strncpy(atom->chain, at_in[i].chain, 2);
                            atom->res_id = at_in[i].resid;
                            atom->pdb_insert = at_in[i].insertion[0];
                            atom->x = ts_in.coords[(3 * i)];
                            atom->y = ts_in.coords[(3 * i) + 1];
                            atom->z = ts_in.coords[(3 * i) + 2];
                            atom->occupancy = at_in[i].occupancy;
                            atom->bfactor = at_in[i].bfactor;
                            strncpy(atom->symbol, pte_get_element_from_number(at_in[i].atomicnumber), 3);

                            atom->charge = at_in[i].charge;
                            atom->mass = at_in[i].mass;
                            atom->radius = at_in[i].radius;
                            atom->electroneg = pte_get_enegativity(atom->symbol);
                            guess_flag += 1;
                            atom->sort_x = -1;

                            atoms_p[iatoms] = atom;
                            pdb->lhetatm[ihetatm] = atom;
                            ihetatm++;
                            iatoms++;
                        }
                        else if (!is_ligand(params->chain_as_ligand, at_in[i].chain[0]))
                        {

                            for (j = 0; j < ST_nb_keep_hetatm; j++)
                            {
                                if (ST_keep_hetatm[j][0] == at_in[i].resname[0] && ST_keep_hetatm[j][1] == at_in[i].resname[1] && ST_keep_hetatm[j][2] == at_in[i].resname[2])
                                {

                                    atom = atoms + iatoms;

                                    strcpy(atom->type, at_in[i].atom_type);

                                    atom->id = i + 1;
                                    strcpy(atom->name, at_in[i].type);
                                    atom->pdb_aloc = at_in[i].altloc[0];
                                    strcpy(atom->res_name, at_in[i].resname);
                                    strncpy(atom->chain, at_in[i].chain, 2);
                                    atom->res_id = at_in[i].resid;
                                    atom->pdb_insert = at_in[i].insertion[0];
                                    atom->x = ts_in.coords[(3 * i)];
                                    atom->y = ts_in.coords[(3 * i) + 1];
                                    atom->z = ts_in.coords[(3 * i) + 2];
                                    atom->occupancy = at_in[i].occupancy;
                                    atom->bfactor = at_in[i].bfactor;
                                    strncpy(atom->symbol, pte_get_element_from_number(at_in[i].atomicnumber), 3);

                                    atom->charge = at_in[i].charge;
                                    atom->mass = at_in[i].mass;
                                    atom->radius = at_in[i].radius;
                                    atom->electroneg = pte_get_enegativity(atom->symbol);
                                    guess_flag += 1;
                                    atom->sort_x = -1;

                                    atoms_p[iatoms] = atom;
                                    pdb->lhetatm[ihetatm] = atom;
                                    ihetatm++;
                                    iatoms++;

                                    break;
                                }
                            }
                        }
                    }
                }
            }
            if (pdb->n_xlig_atoms)
            {
                if ((at_in[i].chain[0] == params->xlig_chain_code[0] && at_in[i].resid == params->xlig_resnumber && params->xlig_resname[0] == at_in[i].resname[0] && params->xlig_resname[1] == at_in[i].resname[1] && params->xlig_resname[2] == at_in[i].resname[2]) || (at_in[i].chain_auth[0] == params->xlig_chain_code[0] && at_in[i].resid_auth == params->xlig_resnumber && params->xlig_resname[0] == at_in[i].resname[0] && params->xlig_resname[1] == at_in[i].resname[1] && params->xlig_resname[2] == at_in[i].resname[2]))
                {
                    // if (params->xlig_resname[0] == resb[0] && params->xlig_resname[1] == resb[1] && params->xlig_resname[2] == resb[2]) {

                    *(pdb->xlig_x + i_explicit_ligand_atom) = ts_in.coords[3 * i];
                    *(pdb->xlig_y + i_explicit_ligand_atom) = ts_in.coords[(3 * i) + 1];
                    *(pdb->xlig_z + i_explicit_ligand_atom) = ts_in.coords[(3 * i) + 2];

                    i_explicit_ligand_atom++;
                }
            }
        }
        else if (strncmp(at_in[i].atom_type, "CRYST1", 6) == 0)
        {
            rpdb_extract_cryst1(pdb_line, &(pdb->alpha), &(pdb->beta), &(pdb->gamma),
                                &(pdb->A), &(pdb->B), &(pdb->C));
        }
        else if (!strncmp(at_in[i].atom_type, "END ", 3))
            break;
    }

    pdb->avg_bfactor = 0.0;
    pdb->min_bfactor = 0.0;
    pdb->max_bfactor = 0.0;
    
    for (i = 0; i < iatoms; i++)
    {
        atom = atoms + i;
        atom->a0 = 0.0;
        atom->dA = 0.0;
        atom->abpa_sourrounding_prob = 0.0;
        atom->abpa = 0;
        pdb->avg_bfactor += atom->bfactor;
        atom->ff_charge = 0.0;
        atom->ff_mass = 0.0;
        atom->ff_radius = 0.0;
        atom->ff_well_depth = 0.0;
        atom->ff_well_depth_set = 0;
        if(atom->bfactor<pdb->min_bfactor){
            pdb->min_bfactor=atom->bfactor;
        }
        if(atom->bfactor>pdb->max_bfactor){
            pdb->max_bfactor=atom->bfactor;
        }
    }
    int num_h_atoms = get_number_of_h_atoms(pdb);
    pdb->avg_bfactor /= (iatoms - num_h_atoms);
    //        pdb->avg_bfactor=0.0;

    /*if(guess_flag>0) {
        fprintf(stderr, ">! Warning: You did not provide a standard PDB file.\nElements were guessed by fpocket, because not provided in the PDB file. \nThere is no guarantee on the results!\n");
    }*/

    if (ligan && keep_lig && (ligfound == 0 || pdb->natm_lig <= 0))
    {
        fprintf(stderr, ">!  Warning: ligand '%s' not found in the pdb...\n", ligan);
        if (pdb->latm_lig)
            fprintf(stderr, "! Ligand list is not NULL however...\n");
        if (ligfound == 1)
            fprintf(stderr, "! And ligfound == 1!! :-/\n");
    }
    else if (ligfound == 1 && iatm_lig <= 0)
    {
        fprintf(stderr, ">! Warning: ligand '%s' has been detected but no atoms \
						has been stored!\n",
                ligan);
    }
    else if ((ligfound == 1 && pdb->natm_lig <= 0) || (pdb->natm_lig <= 0 && iatm_lig > 0))
    {
        fprintf(stderr, ">! Warning: ligand '%s' has been detected in rpdb_read \
						but not in rpdb_open!\n",
                ligan);
    }
    // write_files(at_in,ts_in,inatoms,0,filetype);
    api->close_file_read(h_in);
}

void print_molfile_atom_t(molfile_atom_t *at_in, molfile_timestep_t ts_in, int inatoms)
{

    int j;
    for (j = 0; j < inatoms; j++)
    {
        printf("%d## ", j);
        printf("%f|%f|%f\n", ts_in.coords[3 * j], ts_in.coords[3 * j + 1], ts_in.coords[3 * j + 2]);
        printf("atom TYPE :%s\t", at_in[j].atom_type);
        printf("name : %s\t", at_in[j].name);
        printf("type : %s\t", at_in[j].type);
        printf("resname : %s\t", at_in[j].resname);
        printf("resid : %d\t", at_in[j].resid);
        // printf("segid : %s\t", at_in[j].segid);
        printf("chain : %s\t", at_in[j].chain);
        printf("atomic nb : %d\t", at_in[j].atomicnumber);
        printf("altloc: %s\t", at_in[j].altloc);
        // printf("insertion : %s\t", at_in[j].insertion);
        printf("bfactor : %f\n", at_in[j].bfactor);
        // printf("mass : %f\t", at_in[j].mass);
        // printf("charge : %f\t", at_in[j].charge);
        // printf("radius : %f\t", at_in[j].radius);
        // printf("occupancy : %f\n", at_in[j].occupancy);
    }
}

void write_files(molfile_atom_t *at_in, molfile_timestep_t ts_in, int inatoms, int optflags, char *filetype)
{
    void *h_out;
    const char *filepath = "./data/sample/2P0R_wrote.cif";
    h_out = api->open_file_write(filepath, filetype, inatoms);
    api->write_structure(h_out, optflags, at_in);
    api->write_timestep(h_out, &ts_in);
    api->close_file_write(h_out);
}