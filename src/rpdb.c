
#include "../headers/rpdb.h"

/**

## ----- GENERAL INFORMATIONS
##
## FILE 					rpdb.c
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED			01-04-08
##
## ----- SPECIFICATIONS
## ----- MODIFICATIONS HISTORY
##
##	15-09-08	(p)  Modifications on allocation (casting made C++ compiler compatible)
##	01-04-08	(v)  Added template for comments and creation of history
##	01-01-08	(vp) Created (random date...)
##
## ----- TODO or SUGGESTIONS
##

 */

/**
        A list of HETATM to keep in each case!
        REF Peter? no ref...
 */

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
    "NAD", "004", "00B", "00C", "00E", "00O", "01N", "01W", "02A", "02I", "02K", "02L", "02O", "02V", "02Y", "037", "03E", "03Y", "04R", "04U", "04V", "04X", "05N", "060", "07O", "08M", "08P", "0A", "0A0", "0A1", "0A2", "0A8", "0A9", "0AA", "0AB", "0AC", "0AD", "0AF", "0AH", "0AK", "0AM", "0AP", "0AR", "0AU", "0AV", "0AZ", "0BN", "0C", "0CS", "0DA", "0DC", "0DG", "0DT", "0E5", "0EA", "0EH", "0FL", "0G", "0G5", "0GG", "0KZ", "0LF", "0QL", "0QZ", "0R8", "0RJ", "0SP", "0TD", "0TH", "0TS", "0U", "0U1", "0UH", "0UZ", "0W6", "0WZ", "0X9", "0XL", "0XO", "0XQ", "0Y8", "0Y9", "10C", "11Q", "11W", "125", "126", "127", "128", "12A", "12L", "12X", "12Y", "13E", "143", "175", "18M", "18Q", "192", "193", "19W", "1AC", "1AP", "1C3", "1CC", "1DP", "1E3", "1FC", "1G2", "1G3", "1G8", "1JM", "1L1", "1MA", "1ME", "1MG", "1MH", "1OP", "1PA", "1PI", "1PR", "1RN", "1SC", "1TL", "1TQ", "1TW", "1TX", "1TY", "1U8", "1VR", "1W5", "1WA", "1X6", "1XW", "200", "22G", "23F", "23P", "23S", "28J", "28X", "2AD", "2AG", "2AO", "2AR", "2AS", "2AT", "2AU", "2BD", "2BT", "2BU", "2CO", "2DA", "2DF", "2DM", "2DO", "2DT", "2EG", "2FE", "2FI", "2FM", "2GF", "2GT", "2HF", "2IA", "2JC", "2JF", "2JG", "2JH", "2JJ", "2JN", "2JU", "2JV", "2KK", "2KP", "2KZ", "2L5", "2L6", "2L8", "2L9", "2LA", "2LF", "2LT", "2LU", "2MA", "2MG", "2ML", "2MR", "2MT", "2MU", "2NT", "2OM", "2OR", "2OT", "2P0", "2PI", "2PR", "2QD", "2QY", "2QZ", "2R1", "2R3", "2RA", "2RX", "2SA", "2SG", "2SI", "2SO", "2ST", "2TL", "2TY", "2VA", "2XA", "2YC", "2YF", "2YG", "2YH", "2YJ", "2ZC", "30F", "30V", "31H", "31M", "31Q", "32L", "32S", "32T", "33S", "33W", "33X", "34E", "35Y", "3A5", "3AH", "3AR", "3AU", "3BY", "3CF", "3CT", "3DA", "3DR", "3EG", "3FG", "3GA", "3GL", "3K4", "3MD", "3ME", "3MU", "3MY", "3NF", "3O3", "3PM", "3PX", "3QN", "3TD", "3TY", "3WS", "3X9", "3XH", "3YM", "3ZH", "3ZL", "3ZO", "41H", "41Q", "432", "45W", "47C", "4AC", "4AF", "4AK", "4AR", "4AW", "4BF", "4CF", "4CG", "4CY", "4D4", "4DB", "4DP", "4DU", "4F3", "4FB", "4FW", "4GC", "4GJ", "4HH", "4HJ", "4HL", "4HT", "4IK", "4IN", "4J2", "4KY", "4L0", "4L8", "4LZ", "4M8", "4MF", "4NT", "4NU", "4OC", "4OP", "4OU", "4OV", "4PC", "4PD", "4PE", "4PH", "4SC", "4SU", "4TA", "4U3", "4U7", "4WQ", "50L", "50N", "56A", "574", "5A6", "5AA", "5AB", "5AT", "5BU", "5CF", "5CG", "5CM", "5CS", "5CW", "5DW", "5FA", "5FC", "5FQ", "5FU", "5GG", "5HC", "5HM", "5HP", "5HT", "5HU", "5IC", "5IT", "5IU", "5JO", "5MC", "5MD", "5MU", "5NC", "5OC", "5OH", "5PC", "5PG", "5PY", "5R5", "5SE", "5UA", "5X8", "5XU", "5ZA", "62H", "63G", "63H", "64T", "68Z", "6CL", "6CT", "6CW", "6E4", "6FC", "6FL", "6FU", "6GL", "6HA", "6HB", "6HC", "6HG", "6HN", "6HT", "6IA", "6MA", "6MC", "6MI", "6MT", "6MZ", "6OG", "6PO", "70U", "7AT", "7BG", "7DA", "7GU", "7HA", "7JA", "7MG", "7MN", "81R", "81S", "823", "8AG", "8AN", "8AZ", "8FG", "8MG", "8OG", "8SP", "999", "9AT", "9DN", "9DS", "9NE", "9NF", "9NR", "9NV", "A", "A1P", "A23", "A2L", "A2M", "A34", "A35", "A38", "A39", "A3A", "A3P", "A40", "A43", "A44", "A47", "A5L", "A5M", "A5N", "A5O", "A66", "A6A", "A6C", "A6G", "A6U", "A7E", "A8E", "A9D", "A9Z", "AA3", "AA4", "AA6", "AAB", "AAR", "AB7", "ABA", "ABR", "ABS", "ABT", "AC5", "ACA", "ACB", "ACL", "AD2", "ADD", "ADX", "AE5", "AEA", "AEI", "AET", "AF2", "AFA", "AFF", "AFG", "AGD", "AGM", "AGQ", "AGT", "AHB", "AHH", "AHO", "AHP", "AIB", "AJE", "AKL", "ALA", "ALC", "ALM", "ALN", "ALO", "ALS", "ALT", "ALY", "AN6", "AN8", "AP7", "APH", "API", "APK", "APM", "APO", "APP", "AR2", "AR4", "ARG", "ARM", "ARO", "ARV", "AS", "AS2", "AS7", "AS9", "ASA", "ASB", "ASI", "ASK", "ASL", "ASM", "ASN", "ASP", "ASQ", "ASU", "ASX", "ATD", "ATL", "ATM", "AVC", "AVN", "AYA", "AYG", "AZH", "AZK", "AZS", "AZY", "B1F", "B1P", "B2N", "B3A", "B3E", "B3K", "B3L", "B3M", "B3Q", "B3S", "B3T", "B3U", "B3X", "B3Y", "B7C", "BB6", "BB7", "BB8", "BB9", "BBC", "BCS", "BCX", "BE2", "BFD", "BG1", "BGM", "BH2", "BHD", "BIF", "BIL", "BIU", "BJH", "BL2", "BMN", "BMP", "BMQ", "BMT", "BNN", "BOE", "BP5", "BPE", "BRU", "BSE", "BT5", "BTA", "BTC", "BTK", "BTR", "BUC", "BUG", "BVP", "BYR", "BZG", "C", "C12", "C1T", "C1X", "C22", "C25", "C2L", "C2N", "C2S", "C31", "C32", "C34", "C36", "C37", "C38", "C3Y", "C42", "C43", "C45", "C46", "C49", "C4R", "C4S", "C5C", "C5L", "C66", "C6C", "C6G", "C99", "CAB", "CAF", "CAR", "CAS", "CAY", "CB2", "CBR", "CBV", "CCC", "CCL", "CCS", "CCY", "CDE", "CDV", "CDW", "CEA", "CFL", "CFY", "CFZ", "CG1", "CGA", "CGH", "CGU", "CGV", "CH", "CH6", "CH7", "CHG", "CHP", "CIR", "CJO", "CLB", "CLD", "CLE", "CLG", "CLH", "CLV", "CM0", "CME", "CMH", "CML", "CMR", "CMT", "CNG", "CNU", "CP1", "CPC", "CPI", "CQ1", "CQ2", "CQR", "CR0", "CR2", "CR5", "CR7", "CR8", "CRF", "CRG", "CRK", "CRO", "CRQ", "CRU", "CRW", "CRX", "CS0", "CS1", "CS3", "CS4", "CS8", "CSA", "CSB", "CSD", "CSE", "CSF", "CSH", "CSJ", "CSK", "CSL", "CSM", "CSO", "CSP", "CSR", "CSS", "CSU", "CSW", "CSX", "CSY", "CSZ", "CTE", "CTG", "CTH", "CTT", "CUC", "CUD", "CVC", "CWD", "CWR", "CX2", "CXM", "CY0", "CY1", "CY3", "CY4", "CYA", "CYF", "CYG", "CYJ", "CYM", "CYQ", "CYR", "CYS", "CYW", "CZ2", "CZO", "CZZ", "D00", "D11", "D1P", "D2T", "D3", "D33", "D3N", "D3P", "D4M", "D4P", "DA", "DA2", "DAB", "DAH", "DAL", "DAM", "DAR", "DAS", "DBB", "DBM", "DBS", "DBU", "DBY", "DBZ", "DC", "DC2", "DCG", "DCT", "DCY", "DDE", "DDG", "DDN", "DDX", "DDZ", "DFC", "DFF", "DFG", "DFI", "DFO", "DFT", "DG", "DG8", "DGH", "DGI", "DGL", "DGN", "DGP", "DHA", "DHI", "DHL", "DHN", "DHP", "DHU", "DHV", "DI", "DI7", "DI8", "DIL", "DIR", "DIV", "DJF", "DLE", "DLS", "DLY", "DM0", "DMH", "DMK", "DMT", "DN", "DNE", "DNG", "DNL", "DNP", "DNR", "DNS", "DNW", "DO2", "DOA", "DOC", "DOH", "DON", "DPB", "DPL", "DPN", "DPP", "DPQ", "DPR", "DPY", "DRM", "DRP", "DRT", "DRZ", "DSE", "DSG", "DSN", "DSP", "DT", "DTH", "DTR", "DTY", "DU", "DUZ", "DVA", "DXD", "DXN", "DYA", "DYG", "DYL", "DYS", "DZM", "E", "E1X", "ECC", "ECX", "EDA", "EDC", "EDI", "EFC", "EHG", "EHP", "EIT", "ELY", "EME", "ENA", "ENP", "ENQ", "ESB", "ESC", "EXC", "EXY", "EYG", "EYS", "F2F", "F2Y", "F3H", "F3M", "F3N", "F3O", "F3T", "F4H", "F5H", "F6H", "FA2", "FA5", "FAG", "FAI", "FAK", "FAX", "FB5", "FB6", "FCL", "FDG", "FDL", "FFD", "FFM", "FGA", "FGL", "FGP", "FH7", "FHL", "FHO", "FHU", "FIO", "FLA", "FLE", "FLT", "FME", "FMG", "FMU", "FNU", "FOE", "FOX", "FP9", "FPK", "FPR", "FRD", "FT6", "FTR", "FTY", "FVA", "FZN", "G", "G25", "G2L", "G2S", "G31", "G32", "G33", "G35", "G36", "G38", "G42", "G46", "G47", "G48", "G49", "G4P", "G7M", "G8M", "GAO", "GAU", "GCK", "GCM", "GDO", "GDP", "GDR", "GEE", "GF2", "GFL", "GFT", "GGL", "GH3", "GHC", "GHG", "GHP", "GHW", "GL3", "GLH", "GLJ", "GLM", "GLN", "GLQ", "GLU", "GLX", "GLY", "GLZ", "GMA", "GME", "GMS", "GMU", "GN7", "GNC", "GND", "GNE", "GOM", "GPL", "GRB", "GS", "GSC", "GSR", "GSS", "GSU", "GT9", "GU0", "GU1", "GU2", "GU4", "GU5", "GU8", "GU9", "GVL", "GX1", "GYC", "GYS", "H14", "H2U", "H5M", "HAC", "HAR", "HBN", "HCL", "HCM", "HCS", "HDP", "HEU", "HFA", "HG7", "HGL", "HGM", "HGY", "HHI", "HHK", "HIA", "HIC", "HIP", "HIQ", "HIS", "HIX", "HL2", "HLU", "HLX", "HM8", "HM9", "HMF", "HMR", "HN0", "HN1", "HNC", "HOL", "HOX", "HPC", "HPE", "HPQ", "HQA", "HR7", "HRG", "HRP", "HS8", "HS9", "HSE", "HSK", "HSL", "HSO", "HSV", "HT7", "HTI", "HTN", "HTR", "HTY", "HV5", "HVA", "HY3", "HYP", "HZP", "I", "I2M", "I4G", "I58", "I5C", "IAM", "IAR", "IAS", "IC", "ICY", "IEL", "IEY", "IG", "IGL", "IGU", "IIC", "IIL", "ILE", "ILG", "ILX", "IMC", "IML", "IOR", "IOY", "IPG", "IPN", "IRN", "IT1", "IU", "IYR", "IYT", "IZO", "JDT", "JJJ", "JJK", "JJL", "JLN", "JW5", "K1R", "KAG", "KBE", "KCR", "KCX", "KCY", "KFP", "KGC", "KNB", "KOR", "KPF", "KPI", "KPY", "KST", "KWS", "KYN", "KYQ", "L2A", "L3O", "L5P", "LA2", "LAA", "LAG", "LAL", "LAY", "LBY", "LC", "LCA", "LCC", "LCG", "LCH", "LCK", "LCX", "LDH", "LE1", "LED", "LEF", "LEH", "LEI", "LEM", "LET", "LEU", "LG", "LGP", "LGY", "LHC", "LHO", "LHU", "LKC", "LLO", "LLP", "LLY", "LLZ", "LM2", "LME", "LMF", "LMQ", "LMS", "LNE", "LNM", "LP6", "LPD", "LPG", "LPH", "LPL", "LPS", "LRK", "LSO", "LTA", "LTP", "LTR", "LVG", "LVN", "LWM", "LYF", "LYH", "LYM", "LYN", "LYO", "LYR", "LYS", "LYU", "LYV", "LYX", "LYZ", "M0H", "M1G", "M2G", "M2L", "M2S", "M30", "M3L", "M3O", "M4C", "M5M", "MA6", "MA7", "MAA", "MAD", "MAI", "MBQ", "MBZ", "MC1", "MCG", "MCL", "MCS", "MCY", "MD0", "MD3", "MD5", "MD6", "MDF", "MDH", "MDJ", "MDK", "MDO", "MDQ", "MDR", "MDU", "MDV", "ME0", "ME6", "MEA", "MED", "MEG", "MEN", "MEP", "MEQ", "MET", "MEU", "MF3", "MF7", "MFC", "MFT", "MG1", "MGG", "MGN", "MGQ", "MGV", "MGY", "MH1", "MH6", "MH8", "MHL", "MHO", "MHS", "MHU", "MHV", "MHW", "MIA", "MIR", "MIS", "MK8", "MKD", "ML3", "MLE", "MLL", "MLU", "MLY", "MLZ", "MM7", "MME", "MMO", "MMT", "MND", "MNL", "MNU", "MNV", "MOD", "MOZ", "MP4", "MP8", "MPH", "MPJ", "MPQ", "MRG", "MSA", "MSE", "MSL", "MSO", "MSP", "MT2", "MTR", "MTU", "MTY", "MV9", "MVA", "MYK", "MYN", "N", "N10", "N2C", "N4S", "N5I", "N5M", "N6G", "N7P", "N80", "N8P", "NA8", "NAL", "NAM", "NB8", "NBQ", "NC1", "NCB", "NCU", "NCX", "NCY", "NDF", "NDN", "NDU", "NEM", "NEP", "NF2", "NFA", "NHL", "NIY", "NKS", "NLB", "NLE", "NLN", "NLO", "NLP", "NLQ", "NLY", "NMC", "NMM", "NMS", "NMT", "NNH", "NOT", "NP3", "NPH", "NPI", "NR1", "NRG", "NRI", "NRP", "NRQ", "NSK", "NTR", "NTT", "NTY", "NVA", "NWD", "NYB", "NYC", "NYG", "NYM", "NYS", "NZC", "NZH", "O12", "O2C", "O2G", "OAD", "OAS", "OBF", "OBS", "OCS", "OCY", "ODP", "OEM", "OFM", "OGX", "OHI", "OHS", "OHU", "OIC", "OIM", "OIP", "OLD", "OLE", "OLT", "OLZ", "OMC", "OMG", "OMH", "OMT", "OMU", "OMX", "OMY", "OMZ", "ONE", "ONH", "ONL", "ORD", "ORN", "ORQ", "OSE", "OTB", "OTH", "OTY", "OXX", "OYL", "P", "P0A", "P1L", "P1P", "P2Q", "P2T", "P2U", "P2Y", "P3Q", "P4E", "P4F", "P5P", "P9G", "PAQ", "PAS", "PAT", "PBB", "PBF", "PBT", "PCA", "PCC", "PCE", "PCS", "PDD", "PDL", "PDU", "PDW", "PE1", "PEC", "PF5", "PFF", "PG1", "PG7", "PG9", "PGN", "PGP", "PGY", "PH6", "PH8", "PHA", "PHD", "PHE", "PHI", "PHL", "PIA", "PIV", "PLJ", "PM3", "PMT", "POM", "PPN", "PPU", "PPW", "PQ1", "PR3", "PR4", "PR5", "PR7", "PR9", "PRJ", "PRK", "PRN", "PRO", "PRQ", "PRR", "PRS", "PRV", "PSH", "PST", "PSU", "PSW", "PTH", "PTM", "PTR", "PU", "PUY", "PVH", "PVL", "PVX", "PXU", "PYA", "PYH", "PYL", "PYO", "PYX", "PYY", "QAC", "QBT", "QCS", "QDS", "QFG", "QIL", "QLG", "QMM", "QPA", "QPH", "QUO", "QV4", "R", "R1A", "R2P", "R2T", "R4K", "RBD", "RC7", "RCE", "RDG", "RE0", "RE3", "RGL", "RIA", "RMP", "RON", "RPC", "RSP", "RSQ", "RT", "RT0", "RTP", "RUS", "RVX", "RZ4", "S12", "S1H", "S2C", "S2D", "S2M", "S2P", "S4A", "S4C", "S4G", "S4U", "S6G", "S8M", "SAC", "SAH", "SAR", "SAY", "SBD", "SBL", "SC", "SCH", "SCS", "SCY", "SD2", "SD4", "SDE", "SDG", "SDH", "SDP", "SE7", "SEB", "SEC", "SEE", "SEG", "SEL", "SEM", "SEN", "SEP", "SER", "SET", "SFE", "SGB", "SHC", "SHP", "SHR", "SIB", "SIC", "SLL", "SLR", "SLZ", "SMC", "SME", "SMF", "SMP", "SMT", "SNC", "SNN", "SOC", "SOS", "SOY", "SPT", "SRA", "SRZ", "SSU", "STY", "SUB", "SUI", "SUN", "SUR", "SUS", "SVA", "SVV", "SVW", "SVX", "SVY", "SVZ", "SWG", "SXE", "SYS", "T", "T0I", "T0T", "T11", "T23", "T2S", "T2T", "T31", "T32", "T36", "T37", "T38", "T39", "T3P", "T41", "T48", "T49", "T4S", "T5O", "T5S", "T64", "T66", "T6A", "TA3", "TA4", "TAF", "TAL", "TAV", "TBG", "TBM", "TC1", "TCP", "TCQ", "TCR", "TCY", "TDD", "TDF", "TDY", "TED", "TEF", "TFE", "TFF", "TFO", "TFQ", "TFR", "TFT", "TGP", "TH5", "TH6", "THC", "THO", "THP", "THR", "THX", "THZ", "TIH", "TIS", "TLB", "TLC", "TLN", "TLY", "TMB", "TMD", "TNB", "TNR", "TNY", "TOQ", "TOX", "TP1", "TPC", "TPG", "TPH", "TPJ", "TPK", "TPL", "TPO", "TPQ", "TQI", "TQQ", "TQZ", "TRF", "TRG", "TRN", "TRO", "TRP", "TRQ", "TRW", "TRX", "TRY", "TS", "TS9", "TST", "TSY", "TT", "TTD", "TTI", "TTM", "TTQ", "TTS", "TX2", "TXY", "TY1", "TY2", "TY3", "TY5", "TY8", "TY9", "TYB", "TYI", "TYJ", "TYN", "TYO", "TYQ", "TYR", "TYS", "TYT", "TYU", "TYX", "TYY", "TZB", "TZO", "U", "U25", "U2L", "U2N", "U2P", "U2X", "U31", "U33", "U34", "U36", "U37", "U3X", "U8U", "UAL", "UAR", "UBD", "UBI", "UBR", "UCL", "UD5", "UDP", "UDS", "UF0", "UF2", "UFP", "UFR", "UFT", "UGY", "UM1", "UM2", "UMA", "UMS", "UMX", "UN1", "UN2", "UNK", "UOX", "UPE", "UPS", "UPV", "UR3", "URD", "URU", "URX", "US1", "US2", "US3", "US4", "US5", "USM", "UU4", "UU5", "UVX", "V3L", "VAD", "VAF", "VAH", "VAL", "VB1", "VDL", "VET", "VH0", "VLL", "VLM", "VMS", "VOL", "VR0", "WCR", "WFP", "WLU", "WPA", "WRP", "WVL", "X", "X2W", "X4A", "X9Q", "XAD", "XAE", "XAL", "XAR", "XCL", "XCN", "XCR", "XCS", "XCT", "XCY", "XDT", "XGA", "XGL", "XGR", "XGU", "XPB", "XPL", "XPR", "XSN", "XTF", "XTH", "XTL", "XTR", "XTS", "XTY", "XUA", "XUG", "XW1", "XX1", "XXA", "XXY", "XYG", "Y", "Y28", "Y5P", "YCM", "YCO", "YCP", "YG", "YNM", "YOF", "YPR", "YPZ", "YRR", "YTH", "YYA", "YYG", "Z", "Z01", "Z3E", "Z70", "ZAD", "ZAE", "ZAL", "ZBC", "ZBU", "ZBZ", "ZCL", "ZCY", "ZDU", "ZFB", "ZGL", "ZGU", "ZHP", "ZTH", "ZU0", "ZUK", "ZYJ", "ZYK", "ZZD", "ZZJ", "ZZU"
};

static const int ST_nb_keep_hetatm = 1962; //121

/**
   ## FUNCTION:
        rpdb_extract_pdb_atom

   ## SPECIFICATION:
        Extract all information given in a pdb ATOM or HETATM line, and store them
        in given pointers. User must therefore provide enough memory in parameter.
        PDB last known standart:

        COLUMNS      DATA TYPE        FIELD      DEFINITION

        1 -  6      Record name      "ATOM    "
        7 - 11      Integer          serial     Atom serial number.
        13 - 16      Atom             name       Atom name.
        17           Character        altLoc     Alternate location indicator.
        18 - 20      Residue name     resName    Residue name.
        22           Character        chainID    Chain identifier.
        23 - 26      Integer          resSeq     Residue sequence number.
        27           AChar            iCode      Code for insertion of residues.
        31 - 38      Real(8.3)        x          Orthogonal coordinates for X in
                                                                                         Angstroms
        39 - 46      Real(8.3)        y          Orthogonal coordinates for Y in
                                                                                         Angstroms
        47 - 54      Real(8.3)        z          Orthogonal coordinates for Z in
                                                                                         Angstroms
        55 - 60      Real(6.2)        occupancy  Occupancy.
        61 - 66      Real(6.2)        tempFactor Temperature factor.
        77 - 78      LString(2)       element    Element symbol, right-justified.
        79 - 80      LString(2)       charge     Charge on the atom.


   ## PARAMETRES:
        @ char *pdb_line	: The PDB line containings info
        @ int *atm_id		: Pointer to atom ID
        @ char *name		: Pointer to atom name
        @ char *res_name	: Pointer to residue name
        @ char *chain		: Pointer to chain name
        @ char *seg_name	: Pointer to segment
        @ int *res_id 		: Pointer to residue ID
        @ char *insert		: Pointer to insertion code
        @ char *alt_loc		: Pointer to alternate location
        @ char *elem_symbol	: Pointer to element symbol
        @ float *x, *y, *z	: Pointer to coordinates
        @ float *occ		: Pointer to occupency
        @ float *bfactor	: Pointer to b-factor
        @ char *symbol		: Pointer to symbol
        @ float *bfactor	: Pointer to charge
        @ int guess_flag	: Flag if elements were guessed

   ## RETURN:
        void

 */
static const s_mm_atom_type_a mm_atom_type_ST[9] = {
    // Generic type VdWradius Well depth
    { "C", 1.908, 0.086},
    { "F", 1.75, 0.061},
    { "Cl", 1.948, 0.061},
    { "Br", 2.22, 0.320},
    { "I", 2.35, 0.4},
    { "N", 1.824, 0.17},
    { "O", 1.6612, 0.21},
    { "P", 2.1, 0.2},
    { "S", 2.0, 0.25}
};

static const s_mm_atom_charge_a mm_atom_charge_ST[9] = {
    // Generic type VdWradius Well depth
    { "C", 0.0},
    { "Nd", 0.2},
    { "Na", -0.2},
    { "Nc", 0.333},
    { "Oa", -0.2},
    { "Od", 0.2},
    { "Oc", -0.333},
    { "S", 0.0}
};

short get_mm_type_from_element(char *symbol) {
    int i;
    int cur_type = -1;
    for (i = 0; i < NB_MM_TYPES; i++) {
        if (mm_atom_type_ST[i].name[0] == symbol[0]) {
            if (cur_type < 0) cur_type = i;
            if (symbol[1] != '\0') {
                if (mm_atom_type_ST[i].name[1] == symbol[1]) {
                    return (i);
                }
            }
        }
    }
    return (cur_type);
}

s_min_max_coords *float_get_min_max_from_pdb(s_pdb *pdb) {
    if (pdb) {
        int z;
        float minx = 50000., maxx = -50000., miny = 50000., maxy = -50000., minz = 50000., maxz = -50000.;
        int n = pdb->natoms;
        /*if there a no vertices in m before, first allocate some space*/
        for (z = 0; z < n; z++) { /*loop over all vertices*/
            /*store the positions and radius of the vertices*/
            if (minx > pdb->latoms[z].x) minx = pdb->latoms[z].x;
            else if (maxx < pdb->latoms[z].x)maxx = pdb->latoms[z].x;
            if (miny > pdb->latoms[z].y) miny = pdb->latoms[z].y;
            else if (maxy < pdb->latoms[z].y)maxy = pdb->latoms[z].y;
            if (minz > pdb->latoms[z].z) minz = pdb->latoms[z].z;
            else if (maxz < pdb->latoms[z].z)maxz = pdb->latoms[z].z;
        }
        s_min_max_coords *r = (s_min_max_coords *) my_malloc(sizeof (s_min_max_coords));
        r->maxx = maxx;
        r->maxy = maxy;
        r->maxz = maxz;
        r->minx = minx;
        r->miny = miny;
        r->minz = minz;
        return (r);
    }
    return (NULL);
}

s_atom_ptr_list *init_atom_ptr_list() {
    s_atom_ptr_list *ret = my_malloc(sizeof (s_atom_ptr_list));
    ret->natoms = 0;
    ret->latoms = (s_atm **) my_malloc(sizeof (s_atm *));
    return (ret);
}

void create_coord_grid(s_pdb *pdb) {
    init_coord_grid(pdb);
    fill_coord_grid(pdb);
}

void fill_coord_grid(s_pdb *pdb) {
    //    void update_md_grid(s_mdgrid *g, s_mdgrid *refg, c_lst_pockets *pockets, s_mdparams *par) {
    int xidx = 0, yidx = 0, zidx = 0; /*direct indices of the positions in the grid*/
    float vx, vy, vz;
    int i = 0;
    s_pdb_grid *g = pdb->grid;
    short n_max = 25;

    /*loop over all known vertices and CALCULATE the grid positions and increment grid values by 1*/
    /*important : no distance calculations are done here, thus this routine is very fast*/
    for (i = 0; i < pdb->natoms; i++) {
        vx = pdb->latoms[i].x;
        vy = pdb->latoms[i].y;
        vz = pdb->latoms[i].z;

        xidx = (int) roundf((vx - g->origin[0]) / g->resolution); /*calculate the nearest grid point internal coordinates*/
        yidx = (int) roundf((vy - g->origin[1]) / g->resolution);
        zidx = (int) roundf((vz - g->origin[2]) / g->resolution);
        //fprintf(stdout,"here %d:%d %d:%d %d:%d\n",xidx,g->nx,yidx,g->ny,zidx,g->nz);
        fflush(stdout);

        if (g->atom_ptr[xidx][yidx][zidx].natoms == 0) {/*TODO : continue here !! */
            g->atom_ptr[xidx][yidx][zidx].latoms = (s_atm **) my_malloc(sizeof (s_atm *) * n_max);
            g->atom_ptr[xidx][yidx][zidx].latoms[0] = pdb->latoms_p[i];
            g->atom_ptr[xidx][yidx][zidx].natoms = 1;
        } else {
            //            fprintf(stdout,"NUmber of atoms per coord grid point : %d\n",g->atom_ptr[xidx][yidx][zidx].natoms);
            //            fflush(stdout);
            if (g->atom_ptr[xidx][yidx][zidx].natoms < n_max) {
                fflush(stdout);
                *(g->atom_ptr[xidx][yidx][zidx].latoms + g->atom_ptr[xidx][yidx][zidx].natoms) = *(pdb->latoms_p + i);
            } else fprintf(stderr, "exceeding memory size for each grid element");
            g->atom_ptr[xidx][yidx][zidx].natoms += 1;
        }

    }

}

void init_coord_grid(s_pdb *pdb) {
    s_pdb_grid *g = (s_pdb_grid *) my_malloc(sizeof (s_pdb_grid));

    float resolution = 5.0; //fixed for now
    s_min_max_coords *mm;

    mm = float_get_min_max_from_pdb(pdb);


    float xmax = mm->maxx;
    float ymax = mm->maxy;
    float zmax = mm->maxz;
    float xmin = mm->minx;
    float ymin = mm->miny;
    float zmin = mm->minz;

    my_free(mm);
    int cx, cy, cz;

    float span = 5.0;



    g->resolution = resolution;


    g->nx = 1 + (int) (xmax + 30. * span - xmin) / (g->resolution);
    g->ny = 1 + (int) (ymax + 30. * span - ymin) / (g->resolution);
    g->nz = 1 + (int) (zmax + 30. * span - zmin) / (g->resolution);


    g->atom_ptr = (s_atom_ptr_list ***) my_malloc(sizeof (s_atom_ptr_list **) * g->nx);
    for (cx = 0; cx < g->nx; cx++) {
        g->atom_ptr[cx] = (s_atom_ptr_list **) my_malloc(sizeof (s_atom_ptr_list *) * g->ny);
        for (cy = 0; cy < g->ny; cy++) {
            g->atom_ptr[cx][cy] = (s_atom_ptr_list *) my_malloc(sizeof (s_atom_ptr_list) * g->nz);
            for (cz = 0; cz < g->nz; cz++) {
                g->atom_ptr[cx][cy][cz] = *init_atom_ptr_list();

            }
        }
    }

    g->origin = (float *) my_malloc(sizeof (float) *3);

    g->origin[0] = xmin - 15. * span;
    g->origin[1] = ymin - 15. * span;
    g->origin[2] = zmin - 15. * span;


    pdb->grid = g;

}

void rpdb_extract_pdb_atom(char *pdb_line, char *type, int *atm_id, char *name,
        char *alt_loc, char *res_name, char *chain,
        int *res_id, char *insert,
        float *x, float *y, float *z, float *occ,
        float *bfactor, char *symbol, int *charge, int *guess_flag) {
    /* Position:          1         2         3         4         5         6 */
    /* Position: 123456789012345678901234567890123456789012345678901234567890 */
    /* Record:   ATOM    145  N   VAL A  25      32.433  16.336  57.540  1.00 */

    /* Position: 6         7         8 */
    /* Position: 012345678901234567890 */
    /* Record:   0 11.92           N   */

    int rlen = strlen(pdb_line);

    char *prt,
            ctmp;

    /* Record type */
    strncpy(type, pdb_line, 6);

    /* Atom ID */
    prt = pdb_line + 6;
    ctmp = pdb_line[11];
    pdb_line[11] = '\0';
    *atm_id = atoi(prt);
    pdb_line[11] = ctmp;

    /* Atom name */
    strncpy(name, pdb_line + 12, 4);
    name[4] = '\0';
    str_trim(name);

    /* Alternate location identifier */
    *alt_loc = pdb_line[16];

    /* Residue name */
    rpdb_extract_atm_resname(pdb_line, res_name);

    /* Chain name */
    chain[0] = pdb_line[21];
    chain[1] = '\0';

    /* Residue id number */
    prt = pdb_line + 22;
    ctmp = pdb_line[26];
    pdb_line[26] = '\0';
    *res_id = atoi(prt);
    pdb_line[26] = ctmp;

    /* Insertion code */
    *insert = pdb_line[26];

    /* x, y, and z coordinates, occupancy and b-factor */
    rpdb_extract_atom_values(pdb_line, x, y, z, occ, bfactor);

    /* Atomic element symbol (if does not exists, guess it based on
     * atom name */
    if (rlen >= 77) {
        strncpy(symbol, pdb_line + 76, 2);
        symbol[2] = '\0';
        str_trim(symbol); /* remove spaces */
        if (strlen(symbol) < 1) {
            guess_element(name, symbol, res_name);
            *guess_flag += 1;
        }
    } else {
        guess_element(name, symbol, res_name);
        *guess_flag += 1;
    }
    str_trim(symbol); /* remove spaces */

    /* Charge */
    if (rlen >= 79) {
        char buf[4] = "   ";
        if ((pdb_line[78] == ' ' && pdb_line[79] == ' ') || pdb_line[78] == '\n') {
            *charge = 0;
        } else {
            buf[0] = pdb_line[78];
            buf[1] = pdb_line[79];
            buf[2] = '\0';
            *charge = (int) atoi(buf);
        }
    } else *charge = 0;

}

int element_in_kept_res(char *res_name) {
    int i;
    for (i = 0; i < ST_nb_keep_hetatm; i++) {
        if (!strncmp(res_name, ST_keep_hetatm[i], 3)) return 1;
    }
    return 0;
}

/**
   ## FUNCTION:
        guess_element

   ## SPECIFICATION:
        Guess the element of the atom based on atom name. The pattern matched here
        have been taken from the MOE PDB reader.

 	
   ## PARAMETRES:
        @ char *atom_name	: The atom name
        @ char *res_name	: OUTPUT the element guessed

   ## RETURN:
        void (element is the output)

 */
void guess_element(char *aname, char *element, char *res_name) {
    /* Use a temporary variable for atomname, mainly to remove spaces */
    char tmp[strlen(aname) + 1];
    strcpy(tmp, aname);

    str_trim(tmp);
    char *ptmp = tmp;

    /* Move to the second caracter if we find a number */
    if (isdigit(tmp[0])) ptmp = ptmp + 1;

    if (element_in_std_res(res_name)) {
        /* Check if its a valid element for standard residues in proteins */

        int index = is_valid_prot_element(ptmp, 1);
        if (index != -1) {
            element[0] = ptmp[0];
            element[1] = '\0';
            //element[2] = '\0';
            return;
        }
    } else if (element_in_nucl_acid(res_name)) {
        int index = is_valid_nucl_acid_element(ptmp, 1);
        if (index != -1) {
            element[0] = ptmp[0];
            element[1] = '\0';
            //element[2] = '\0';
            return;
        }
    } else {
        int index = is_valid_element(ptmp, 1);
        if (index != -1) {
            strcpy(element, ptmp);
            return;
        }
    }
    /* Here we have a special case... So take the first and second */
    element[0] = ptmp[0];
    element[1] = ptmp[1];
    element[2] = '\0';
}

int is_N(char *aname) { /* N:'[A-G,I-L,N-Z]N#*' */

    if (aname[0] == 'N' && isdigit(aname[1])) return 1;
    if (aname[0] != 'H' && aname[0] != 'M' && aname[1] == 'N'
            && str_is_number(aname, 0)) return 1;

    return 0;
}

int is_O(char *aname) {
    /*
              O:['[A-B,D-G,I-L,N-Z]O*','OP[A-C]#','CO[A-Z,0-9]*','OE##']
     */
    if (aname[0] == 'O') {
        /* TESTING     'OP[A-C]#' */
        if (aname[1] == 'P' && (aname[2] == 'A' || aname[2] == 'B' || aname[2] == 'C')
                && isdigit(aname[3])) {
            return 1;
        }

        /* TESTING     'OE##' */
        if (aname[1] == 'E' && isdigit(aname[2]) && isdigit(aname[3])) return 1;
    } else {
        /* TESTING     '[A-B,D-G,I-L,N-Z]O*' */
        if (aname[0] != 'C' && aname[0] != 'H' && aname[0] != 'M' && aname[1] == 'O')
            return 1;

        /* TESTING     'CO[A-Z,0-9]*' */
        if (aname[0] == 'C' && aname[1] == 'O' && aname[2] != ' ' && aname[3] != ' ')
            return 1;
    }

    return 0;
}

/**
   ## FUNCTION:
        rpdb_extract_atm_resname

   ## SPECIFICATION:
        Extract the residu name for an ATOM or HETATM pdb record. To remember:

        COLUMNS      DATA TYPE        FIELD      DEFINITION

        18 - 20      Residue name     resName    Residue name.

        The memory to store the name has to be provided by the user.

   ## PARAMETRES:
        @ char *pdb_line	: The PDB line containings info
        @ char *res_name	: Pointer to residue name

   ## RETURN:
        void

 */
void rpdb_extract_atm_resname(char *pdb_line, char *res_name) {
    /* Position:          1         2         3         4         5         6 */
    /* Position: 123456789012345678901234567890123456789012345678901234567890 */
    /* Record:   ATOM    145  N   VAL A  25      32.433  16.336  57.540  1.00 */

    /* Position: 6         7         8 */
    /* Position: 012345678901234567890 */
    /* Record:   0 11.92           N   */

    /* Residue name */
    strncpy(res_name, pdb_line + 17, 4);
    res_name[4] = '\0';
    str_trim(res_name);
}



/**
   ## FUNCTION:
        rpdb_extract_atm_resumber

   ## SPECIFICATION:
        Extract the residu number for an ATOM or HETATM pdb record. To remember:

        COLUMNS      DATA TYPE        FIELD      DEFINITION

        23 - 26      Residue number     resSeq    Residue number.

        The memory to store the name has to be provided by the user.

   ## PARAMETRES:
        @ char *pdb_line	: The PDB line containings info
        @ char *res_name	: Pointer to residue name

   ## RETURN:
        void

 */
int rpdb_extract_atm_resumber(char *pdb_line){
     char *prt,
            ctmp;
     int res_id;
     /* Residue id number */
    prt = pdb_line + 22;
    ctmp = pdb_line[26];
    pdb_line[26] = '\0';
    res_id = atoi(prt);
    pdb_line[26] = ctmp;
    return(res_id);
}



/**
   ## FUNCTION:
        rpdb_extract_atom_values

   ## SPECIFICATION:
        Extract coordinates, occupancy and bfactor values from a pdb ATOM or HETATM
        line, and store them in given pointers.

   ## PARAMETRES:
        @ char *pdb_line	: The PDB line containings info
        @ float *x, *y, *z	: Pointer to coordinates
        @ float *occ		: Pointer to occupency
        @ float *bfactor	: Pointer to b-factor

   ## RETURN: void

 */

/**
 * @description extract atom coordinates to xyz parameters from pdb_line
 * @param pdb_line
 * @param x
 * @param y
 * @param z
 */
void rpdb_extract_atom_coordinates(char *pdb_line, float *x, float *y, float *z) {
    /* Position:          1         2         3         4         5         6 */
    /* Position: 123456789012345678901234567890123456789012345678901234567890 */
    /* Record:   ATOM    145  N   VAL A  25      32.433  16.336  57.540  1.00 */

    /* Position: 6         7         8 */
    /* Position: 012345678901234567890 */
    /* Record:   0 11.92           N   */

    char *ptr,
            ctmp;

    ptr = pdb_line + 30;
    ctmp = pdb_line[38];
    pdb_line[38] = '\0';
    *x = (float) atof(ptr);
    pdb_line[38] = ctmp;

    ptr = pdb_line + 38;
    ctmp = pdb_line[46];
    pdb_line[46] = '\0';
    *y = (float) atof(ptr);
    pdb_line[46] = ctmp;

    ptr = pdb_line + 46;
    ctmp = pdb_line[54];
    pdb_line[54] = '\0';
    *z = (float) atof(ptr);
    pdb_line[54] = ctmp;

}

/**
   ## FUNCTION:
        rpdb_extract_atom_values

   ## SPECIFICATION:
        Extract coordinates, occupancy and bfactor values from a pdb ATOM or HETATM
        line, and store them in given pointers.

   ## PARAMETRES:
        @ char *pdb_line	: The PDB line containings info
        @ float *x, *y, *z	: Pointer to coordinates
        @ float *occ		: Pointer to occupency
        @ float *bfactor	: Pointer to b-factor

   ## RETURN: void

 */
void rpdb_extract_atom_values(char *pdb_line, float *x, float *y, float *z,
        float *occ, float *bfactor) {
    /* Position:          1         2         3         4         5         6 */
    /* Position: 123456789012345678901234567890123456789012345678901234567890 */
    /* Record:   ATOM    145  N   VAL A  25      32.433  16.336  57.540  1.00 */

    /* Position: 6         7         8 */
    /* Position: 012345678901234567890 */
    /* Record:   0 11.92           N   */

    char *ptr,
            ctmp;

    ptr = pdb_line + 30;
    ctmp = pdb_line[38];
    pdb_line[38] = '\0';
    *x = (float) atof(ptr);
    pdb_line[38] = ctmp;

    ptr = pdb_line + 38;
    ctmp = pdb_line[46];
    pdb_line[46] = '\0';
    *y = (float) atof(ptr);
    pdb_line[46] = ctmp;

    ptr = pdb_line + 46;
    ctmp = pdb_line[54];
    pdb_line[54] = '\0';
    *z = (float) atof(ptr);
    pdb_line[54] = ctmp;

    ptr = pdb_line + 54;
    ctmp = pdb_line[60];
    pdb_line[60] = '\0';
    *occ = (float) atof(ptr);
    pdb_line[60] = ctmp;

    ptr = pdb_line + 60;
    ctmp = pdb_line[66];
    pdb_line[66] = '\0';
    *bfactor = (float) atof(ptr);
    pdb_line[66] = ctmp;
}

/**
   ## FUNCTION:
        rpdb_extract_cryst1

   ## SPECIFICATION:
        Extract information on a box size from a pdb CRYSTL line, and store them
        in given pointers.

   ## PARAMETRES:
        @ char *pdb_line				: The PDB line containings info
        @ float *alpha, *beta, *gamma	: Pointer to angles
        @ float *A, B, C				: Pointer sides length

   ## RETURN: void

 */
void rpdb_extract_cryst1(char *pdb_line, float *alpha, float *beta, float *gamma,
        float *a, float *b, float *c) {
    /* Position:          1         2         3         4         5         6 */
    /* Position: 123456789012345678901234567890123456789012345678901234567890 */
    /* Record:   ATOM    145  N   VAL A  25      32.433  16.336  57.540  1.00 */

    /* Position: 6         7         8 */
    /* Position: 012345678901234567890 */
    /* Record:   0 11.92           N   */

    char ch, *s;

    s = pdb_line + 6;
    ch = pdb_line[15];
    pdb_line[15] = '\0';
    *a = (float) atof(s);

    s = pdb_line + 15;
    *s = ch;
    ch = pdb_line[24];
    pdb_line[24] = '\0';
    *b = (float) atof(s);

    s = pdb_line + 24;
    *s = ch;
    ch = pdb_line[33];
    pdb_line[33] = '\0';
    *c = (float) atof(s);

    s = pdb_line + 33;
    *s = ch;
    ch = pdb_line[40];
    pdb_line[40] = '\0';
    *alpha = (float) atof(s);

    s = pdb_line + 40;
    *s = ch;
    ch = pdb_line[47];
    pdb_line[47] = '\0';
    *beta = (float) atof(s);

    s = pdb_line + 47;
    *s = ch;
    ch = pdb_line[54];
    pdb_line[54] = '\0';
    *gamma = (float) atof(s);
}

/**
   ## FUNCTION:
        rpdb_open

   ## SPECIFICATION:
        Open a PDB file, alloc memory for all information on this pdb, and store
        several information like the number of atoms, the header, the remark...
        This first reading of PDB rewinds the FILE* pointer. No coordinates are
        actually read.

        Hydrogens are conserved.
        All HETATM are removed, except the given ligand if we have to keep it, and
        important HETATM listed in the static structure at the top of this file.

   ## PARAMETRES:
        @ const char *fpath    : The pdb path.
        @ const char *ligan    : Ligand resname.
        @ const char *keep_lig :  Keep the given ligand or not?

   ## RETURN:
        s_pdb: data containing PDB info.

 */
s_pdb* rpdb_open(char *fpath, const char *ligan, const int keep_lig, int model_number, s_fparams *par) {
    s_pdb *pdb = NULL;

    char buf[M_PDB_BUF_LEN],
            resb[5]; //, chainb[5];

    int nhetatm = 0,
            natoms = 0,
            natm_lig = 0;
    int i;
    float x, y, z;
    int resnbuf=0;
    int model_flag = 0; /*by default we consider that no particular model is read*/
    int model_read = 0; /*flag tracking the status if a current line is read or not*/
    int cur_model_count = 0; /*when reading NMR models, then count on which model you currently are*/
    pdb = (s_pdb *) my_malloc(sizeof (s_pdb));
    ;
    pdb->n_xlig_atoms = 0;
    pdb->xlig_x = NULL;
    pdb->xlig_y = NULL;
    pdb->xlig_z = NULL;

    /* Open the PDB file in read-only mode */
    pdb->fpdb = fopen_pdb_check_case(fpath, "r");
    if (!pdb->fpdb) {
        my_free(pdb);
        fprintf(stderr, "! File %s does not exist\n", fpath);
        return NULL;
    }
    //printf("Model Number : %d\n",model_number);
    if (model_number > 0) model_flag = 1; /*here we indicate that a particular model should be read only*/
    while (fgets(buf, M_PDB_LINE_LEN + 2, pdb->fpdb)) {
        if (!strncmp(buf, "MODEL", 5) && model_number > 0) {
            cur_model_count++;
            //printf("model : %d\n",cur_model_count);
            if (cur_model_count == model_number) model_read = 1;
        }
        if (model_flag == 0 || model_read == 1) {
            if (!strncmp(buf, "ATOM ", 5)) {
                /* Check if this is the first occurence of this atom*/
                rpdb_extract_atm_resname(buf, resb);
                rpdb_extract_atom_coordinates(buf, &x, &y, &z); /*extract and double check coordinates to avoid issues with wrong coordinates*/
                resnbuf=rpdb_extract_atm_resumber(buf);
                
                if ((buf[16] == ' ' || buf[16] == 'A') && x < 9990 && y < 9990 && z < 9990) {
                    /* Atom entry: check if there is a ligand in there (just in case)... */
                    if (ligan && strlen(ligan) > 1 && ligan[0] == resb[0] && ligan[1] == resb[1]
                            && ligan[2] == resb[2]) {

                        if (keep_lig) {
                            natm_lig++;
                            natoms++;
                        }
                    } else if (ligan && strlen(ligan) == 1 && buf[21] == ligan[0]) { /*here we have a protein chain defined as ligand...a bit more complex then*/
                        if (keep_lig) {
                            natm_lig++;
                            natoms++;
                        }
                    } else {
                        natoms++;
                    }
                    /*handle explicit ligand input here*/
                    if (par->xlig_resnumber>-1) {
                        //fprintf(stdout,"%d\n",resnbuf);
//                        if (resb[0] == par->xlig_resname[0] && resb[1] == par->xlig_resname[1] && resb[2] == par->xlig_resname[2]) {
                        if (buf[16] == par->xlig_chain_code[0] && resnbuf == par->xlig_resnumber && par->xlig_resname[0] == resb[0] && par->xlig_resname[1] == resb[1] && par->xlig_resname[2] == resb[2]) {
                            pdb->n_xlig_atoms++;
                            fprintf(stdout,"%d\n",pdb->n_xlig_atoms);
                        }
                    }
                }

            } else if (!strncmp(buf, "HETATM", 6)) {
                /*Check again for the first occurence*/
                rpdb_extract_atom_coordinates(buf, &x, &y, &z); /*extract and double check coordinates to avoid issues with wrong coordinates*/
                if ((buf[16] == ' ' || buf[16] == 'A') && x < 9990 && y < 9990 && z < 9990) {
                    /* Hetatom entry: check if there is a ligand in there too... */
                    rpdb_extract_atm_resname(buf, resb);
                    if (ligan && strlen(ligan) > 1 && keep_lig && ligan[0] == resb[0] && ligan[1] == resb[1]
                            && ligan[2] == resb[2]) {
                        natm_lig++;
                        natoms++;
                    } else if (ligan && strlen(ligan) == 1 && ligan[0] == buf[21]) {
                        if (keep_lig) natm_lig++;
                        natoms++;
                    } else {
                        /* Keep specific HETATM given in the static list ST_keep_hetatm */
                        if (keep_lig && !ligan && strncmp(resb, "HOH", 3) && strncmp(resb, "WAT", 3) && strncmp(resb, "TIP", 3)) {
                            natoms++;
                            nhetatm++;
                        } else {
                            for (i = 0; i < ST_nb_keep_hetatm; i++) {
                                if (ST_keep_hetatm[i][0] == resb[0] && ST_keep_hetatm[i][1]
                                        == resb[1] && ST_keep_hetatm[i][2] == resb[2]) {
                                    nhetatm++;
                                    natoms++;
                                    break;
                                }
                            }
                        }
                    }

                    /*handle explicit ligand input here*/
                    if (par->xlig_resnumber>-1) {
                        if (buf[16] == par->xlig_chain_code[0] && resnbuf == par->xlig_resnumber && par->xlig_resname[0] == resb[0] && par->xlig_resname[1] == resb[1] && par->xlig_resname[2] == resb[2]) {
                            pdb->n_xlig_atoms++;
                            fprintf(stdout,"%d\n",pdb->n_xlig_atoms);
                            fflush(stdout);
                        }
                    }
                }
            }/*
		else if (!strncmp(buf, "HEADER", 6))
			strncpy(pdb->header, buf, M_PDB_BUF_LEN) ;
*/

            else if (model_read == 1 && !strncmp(buf, "ENDMDL", 6)) model_read = 0;
            else if (model_number == 0 && !strncmp(buf, "END", 3)) break;

        }
    }
    if (pdb->n_xlig_atoms) {
        pdb->xlig_x = (float *) my_malloc(sizeof (float )*pdb->n_xlig_atoms);
        pdb->xlig_y = (float *)my_malloc(sizeof (float )*pdb->n_xlig_atoms);
        pdb->xlig_z = (float *)my_malloc(sizeof (float )*pdb->n_xlig_atoms);


    }




    if (natoms == 0) {
        fprintf(stderr, "! File '%s' contains no atoms...\n", fpath);
        my_free(pdb);

        return NULL;
    }


    /* Alloc needed memory */
    pdb->latoms = (s_atm*) my_calloc(natoms, sizeof (s_atm));
    pdb->latoms_p = (s_atm**) my_calloc(natoms, sizeof (s_atm*));

    if (nhetatm > 0) pdb->lhetatm = (s_atm**) my_calloc(nhetatm, sizeof (s_atm*));
    else pdb->lhetatm = NULL;

    if (natm_lig > 0) pdb->latm_lig = (s_atm**) my_calloc(natm_lig, sizeof (s_atm*));
    else pdb->latm_lig = NULL;

    pdb->natoms = natoms;
    pdb->nhetatm = nhetatm;
    pdb->natm_lig = natm_lig;
    strcpy(pdb->fname, fpath);
    rewind(pdb->fpdb);
    return pdb;
}

int get_number_of_h_atoms(s_pdb *pdb) {
    int i, nb_h = 0;
    s_atm *ca = NULL;
    for (i = 0; i < pdb->natoms; i++) {
        ca = (pdb->latoms) + i;

        if (strcmp(ca->symbol, "H") == 0) nb_h++;
    }
    return (nb_h);

}

/**
   ## FUNCTION:
        rpdb_read

   ## SPECIFICATION:
        Read and store information on atoms for a pdb file.
    Curently:
                - Hydrogens present in the PDB are kept
                - HETATM are ignored except for specific cofactor, small molecule...
                  listed in ST_keep_hetatm variable, and for a  given ligand, defined by
                  its resname.
                - Solvent molecules are ignored

   ## PARAMETRES:
        @ s_pdb *pdb           : The structure to fill
        @ const char *ligand   : The ligand resname
        @ const char *keep_lig :  Keep the given ligand or not?

   ## RETURN:

 */
void rpdb_read(s_pdb *pdb, const char *ligan, const int keep_lig, int model_number, s_fparams *params) {
    int i,
            iatoms,
            ihetatm,
            iatm_lig,
            ligfound;

    char pdb_line[M_PDB_BUF_LEN],
            resb[5]; /* Buffer for the current residue name */
    int model_flag = 0; /*by default we consider that no particular model is read*/
    int model_read = 0; /*flag tracking the status if a current line is read or not*/
    int cur_model_count = 0; /*when reading NMR models, then count on which model you currently are*/
    s_atm *atom = NULL;
    s_atm *atoms = pdb->latoms;
    s_atm **atoms_p = pdb->latoms_p;
    s_atm **atm_lig = pdb->latm_lig;
    int guess_flag = 0;
    iatoms = 0;
    int i_explicit_ligand_atom = 0; //counter to know on which atom of the ligand we are to define an explicit pocket
    ihetatm = 0;
    iatm_lig = 0;
    ligfound = 0;
    int resnbuf=0;

    float tmpx, tmpy, tmpz;
    /* Loop over the pdb file */
    if (model_number > 0) model_flag = 1; /*here we indicate that a particular model should be read only*/
    while (fgets(pdb_line, M_PDB_LINE_LEN + 2, pdb->fpdb)) {
        if (!strncmp(pdb_line, "MODEL", 5) && model_number > 0) {
            cur_model_count++;
            if (cur_model_count == model_number) model_read = 1;
        }
        if (model_flag == 0 || model_read == 1) {
            if (strncmp(pdb_line, "ATOM ", 5) == 0) {
                rpdb_extract_atom_coordinates(pdb_line, &tmpx, &tmpy, &tmpz); /*extract and double check coordinates to avoid issues with wrong coordinates*/

                if ((pdb_line[16] == ' ' || pdb_line[16] == 'A') && tmpx < 9990 && tmpy < 9990 && tmpz < 9990) { /*if within first occurence*/
                    /* Store ATOM entry */
                    rpdb_extract_atm_resname(pdb_line, resb);
                    resnbuf=rpdb_extract_atm_resumber(pdb_line);

                    if (pdb->n_xlig_atoms) {
                        if (pdb_line[16] == params->xlig_chain_code[0] && resnbuf == params->xlig_resnumber && params->xlig_resname[0] == resb[0] && params->xlig_resname[1] == resb[1] && params->xlig_resname[2] == resb[2]) {
                            rpdb_extract_atom_coordinates(pdb_line,(pdb->xlig_x+i_explicit_ligand_atom),(pdb->xlig_y+i_explicit_ligand_atom),(pdb->xlig_z+i_explicit_ligand_atom));
                            i_explicit_ligand_atom++;
                        }
                    }

                    /* Check if the desired ligand is in such an entry */
                    if (ligan && strlen(ligan) > 1 && ligan[0] == resb[0] && ligan[1] == resb[1]
                            && ligan[2] == resb[2]) {
                        if (keep_lig) {
                            atom = atoms + iatoms;

                            /* Read atom information */
                            rpdb_extract_pdb_atom(pdb_line, atom->type, &(atom->id),
                                    atom->name, &(atom->pdb_aloc), atom->res_name,
                                    atom->chain, &(atom->res_id), &(atom->pdb_insert),
                                    &(atom->x), &(atom->y), &(atom->z),
                                    &(atom->occupancy), &(atom->bfactor), atom->symbol,
                                    &(atom->charge), &guess_flag);

                            /* Store additional information not given in the pdb */
                            atom->mass = pte_get_mass(atom->symbol);
                            atom->radius = pte_get_vdw_ray(atom->symbol);
                            atom->electroneg = pte_get_enegativity(atom->symbol);
                            atom->sort_x = -1;

                            atoms_p[iatoms] = atom;
                            iatoms++;

                            atm_lig[iatm_lig] = atom;
                            iatm_lig++;
                            ligfound = 1;
                        }

                    } else if (ligan && strlen(ligan) == 1 && pdb_line[21] == ligan[0]) { /*here we have a protein chain defined as ligand...a bit more complex then*/
                        if (keep_lig) {
                            atom = atoms + iatoms;

                            /* Read atom information */
                            rpdb_extract_pdb_atom(pdb_line, atom->type, &(atom->id),
                                    atom->name, &(atom->pdb_aloc), atom->res_name,
                                    atom->chain, &(atom->res_id), &(atom->pdb_insert),
                                    &(atom->x), &(atom->y), &(atom->z),
                                    &(atom->occupancy), &(atom->bfactor), atom->symbol,
                                    &(atom->charge), &guess_flag);

                            /* Store additional information not given in the pdb */
                            atom->mass = pte_get_mass(atom->symbol);
                            atom->radius = pte_get_vdw_ray(atom->symbol);
                            atom->electroneg = pte_get_enegativity(atom->symbol);
                            atom->sort_x = -1;

                            atoms_p[iatoms] = atom;
                            iatoms++;

                            atm_lig[iatm_lig] = atom;
                            iatm_lig++;
                            ligfound = 1;

                        }
                    } else {

                        /* A simple atom not supposed to be stored as a ligand */
                        atom = atoms + iatoms;
                        rpdb_extract_pdb_atom(pdb_line, atom->type, &(atom->id),
                                atom->name, &(atom->pdb_aloc), atom->res_name,
                                atom->chain, &(atom->res_id), &(atom->pdb_insert),
                                &(atom->x), &(atom->y), &(atom->z), &(atom->occupancy),
                                &(atom->bfactor), atom->symbol, &(atom->charge), &guess_flag);

                        /* Store additional information not given in the pdb */
                        atom->mass = pte_get_mass(atom->symbol);
                        atom->radius = pte_get_vdw_ray(atom->symbol);
                        atom->electroneg = pte_get_enegativity(atom->symbol);
                        atom->sort_x = -1;

                        atoms_p[iatoms] = atom;
                        iatoms++;
                    }
                }


            } else if (strncmp(pdb_line, "HETATM", 6) == 0) {
                rpdb_extract_atom_coordinates(pdb_line, &tmpx, &tmpy, &tmpz); /*extract and double check coordinates to avoid issues with wrong coordinates*/
                if ((pdb_line[16] == ' ' || pdb_line[16] == 'A') && tmpx < 9990 && tmpy < 9990 && tmpz < 9990) {/*first occurence*/
                    /* Check HETATM entry */
                    rpdb_extract_atm_resname(pdb_line, resb);
                    resnbuf=rpdb_extract_atm_resumber(pdb_line);

                    if (pdb->n_xlig_atoms) {
                        if (pdb_line[16] == params->xlig_chain_code[0] && resnbuf == params->xlig_resnumber && params->xlig_resname[0] == resb[0] && params->xlig_resname[1] == resb[1] && params->xlig_resname[2] == resb[2]) {                    
                        //if (params->xlig_resname[0] == resb[0] && params->xlig_resname[1] == resb[1] && params->xlig_resname[2] == resb[2]) {
                            
                            rpdb_extract_atom_coordinates(pdb_line,(pdb->xlig_x+i_explicit_ligand_atom),(pdb->xlig_y+i_explicit_ligand_atom),(pdb->xlig_z+i_explicit_ligand_atom));
                            
                            i_explicit_ligand_atom++;
                        }
                            
                    }    
                            //fflush(stdout);
                    /* Check if the desired ligand is in HETATM entry */
                    if (ligan && strlen(ligan) > 1 && keep_lig && ligan[0] == resb[0] && ligan[1] == resb[1]
                            && ligan[2] == resb[2]) {

                        atom = atoms + iatoms;
                        rpdb_extract_pdb_atom(pdb_line, atom->type, &(atom->id),
                                atom->name, &(atom->pdb_aloc), atom->res_name,
                                atom->chain, &(atom->res_id), &(atom->pdb_insert),
                                &(atom->x), &(atom->y), &(atom->z), &(atom->occupancy),
                                &(atom->bfactor), atom->symbol, &(atom->charge), &guess_flag);

                        /* Store additional information not given in the pdb */
                        atom->mass = pte_get_mass(atom->symbol);
                        atom->radius = pte_get_vdw_ray(atom->symbol);
                        atom->electroneg = pte_get_enegativity(atom->symbol);
                        atom->sort_x = -1;

                        atoms_p[iatoms] = atom;
                        atm_lig[iatm_lig] = atom;

                        iatm_lig++;
                        iatoms++;
                        ligfound = 1;
                    } else if (ligan && strlen(ligan) == 1 && ligan[0] == pdb_line[21]) {
                        if (keep_lig) {

                            atom = atoms + iatoms;
                            rpdb_extract_pdb_atom(pdb_line, atom->type, &(atom->id),
                                    atom->name, &(atom->pdb_aloc), atom->res_name,
                                    atom->chain, &(atom->res_id), &(atom->pdb_insert),
                                    &(atom->x), &(atom->y), &(atom->z), &(atom->occupancy),
                                    &(atom->bfactor), atom->symbol, &(atom->charge), &guess_flag);

                            /* Store additional information not given in the pdb */
                            atom->mass = pte_get_mass(atom->symbol);
                            atom->radius = pte_get_vdw_ray(atom->symbol);
                            atom->electroneg = pte_get_enegativity(atom->symbol);
                            atom->sort_x = -1;

                            atoms_p[iatoms] = atom;
                            atm_lig[iatm_lig] = atom;

                            iatm_lig++;
                            iatoms++;
                            ligfound = 1;
                        }
                    } else if (pdb->lhetatm) {

                        /* Keep specific HETATM given in the static list ST_keep_hetatm. */
                        if (keep_lig && !ligan && strncmp(resb, "HOH", 3) && strncmp(resb, "WAT", 3) && strncmp(resb, "TIP", 3)) {
                            atom = atoms + iatoms;
                            rpdb_extract_pdb_atom(pdb_line, atom->type, &(atom->id),
                                    atom->name, &(atom->pdb_aloc), atom->res_name,
                                    atom->chain, &(atom->res_id), &(atom->pdb_insert),
                                    &(atom->x), &(atom->y), &(atom->z),
                                    &(atom->occupancy), &(atom->bfactor),
                                    atom->symbol, &(atom->charge), &guess_flag);

                            /* Store additional information not given in the pdb */
                            atom->mass = pte_get_mass(atom->symbol);
                            atom->radius = pte_get_vdw_ray(atom->symbol);
                            atom->electroneg = pte_get_enegativity(atom->symbol);
                            atom->sort_x = -1;

                            atoms_p[iatoms] = atom;
                            pdb->lhetatm[ihetatm] = atom;
                            ihetatm++;
                            iatoms++;
                        } else {
                            for (i = 0; i < ST_nb_keep_hetatm; i++) {
                                if (ST_keep_hetatm[i][0] == resb[0] && ST_keep_hetatm[i][1]
                                        == resb[1] && ST_keep_hetatm[i][2] == resb[2]) {
                                    atom = atoms + iatoms;
                                    rpdb_extract_pdb_atom(pdb_line, atom->type, &(atom->id),
                                            atom->name, &(atom->pdb_aloc), atom->res_name,
                                            atom->chain, &(atom->res_id), &(atom->pdb_insert),
                                            &(atom->x), &(atom->y), &(atom->z),
                                            &(atom->occupancy), &(atom->bfactor),
                                            atom->symbol, &(atom->charge), &guess_flag);

                                    /* Store additional information not given in the pdb */
                                    atom->mass = pte_get_mass(atom->symbol);
                                    atom->radius = pte_get_vdw_ray(atom->symbol);
                                    atom->electroneg = pte_get_enegativity(atom->symbol);
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
            } else if (strncmp(pdb_line, "CRYST1", 6) == 0) {
                rpdb_extract_cryst1(pdb_line, &(pdb->alpha), &(pdb->beta), &(pdb->gamma),
                        &(pdb->A), &(pdb->B), &(pdb->C));
            } else if (model_read == 1 && !strncmp(pdb_line, "ENDMDL", 6)) model_read = 0;
            else if (model_number == 0 && !strncmp(pdb_line, "END ", 3)) break;
        }
    }
    pdb->avg_bfactor = 0.0;
    for (i = 0; i < iatoms; i++) {
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

    }
    int num_h_atoms = get_number_of_h_atoms(pdb);
    pdb->avg_bfactor /= (iatoms - num_h_atoms);
    //        pdb->avg_bfactor=0.0;

    /*if(guess_flag>0) {
        fprintf(stderr, ">! Warning: You did not provide a standard PDB file.\nElements were guessed by fpocket, because not provided in the PDB file. \nThere is no guarantee on the results!\n");
    }*/

    if (ligan && keep_lig && (ligfound == 0 || pdb->natm_lig <= 0)) {
        fprintf(stderr, ">! Warning: ligand '%s' not found in the pdb...\n", ligan);
        if (pdb->latm_lig) fprintf(stderr, "! Ligand list is not NULL however...\n");
        if (ligfound == 1) fprintf(stderr, "! And ligfound == 1!! :-/\n");
    } else if (ligfound == 1 && iatm_lig <= 0) {
        fprintf(stderr, ">! Warning: ligand '%s' has been detected but no atoms \
						has been stored!\n", ligan);
    } else if ((ligfound == 1 && pdb->natm_lig <= 0) || (pdb->natm_lig <= 0
            && iatm_lig > 0)) {
        fprintf(stderr, ">! Warning: ligand '%s' has been detected in rpdb_read \
						but not in rpdb_open!\n", ligan);
    }

}

void rpdb_print(s_pdb * pdb) {
    int i;
    fprintf(stdout, "PDB file path: %s\n", pdb->fname);
    fprintf(stdout, "Number of atoms : %d\n", pdb->natoms);
    fprintf(stdout, "NUmber of HETATMS : %d\n", pdb->nhetatm);
    fprintf(stdout, "Number of ligand atoms : %d\n", pdb->natm_lig);

    for (i = 0; i < pdb->natoms; i++) {
        fprintf(stdout, "Atom %d: %f %f %f\t", pdb->latoms[i].id, pdb->latoms[i].x, pdb->latoms[i].y, pdb->latoms[i].z);
    }



}

/**
   ## FUNCTION:
        free_pdb_atoms

   ## SPECIFICATION:
        Free memory for s_pdb structure

   ## PARAMETRES:
        @ s_pdb *pdb: pdb struct to free

   ## RETURN:
        void

 */
void free_pdb_atoms(s_pdb * pdb) {
    if (pdb) {
        if (pdb->lhetatm) {
            my_free(pdb->lhetatm);
            pdb->lhetatm = NULL;
        }

        if (pdb->latoms) {
            my_free(pdb->latoms);
            pdb->latoms = NULL;
        }
        if (pdb->latm_lig) {
            my_free(pdb->latm_lig);
            pdb->latm_lig = NULL;
        }
        if (pdb->fpdb) {
            fclose(pdb->fpdb);
            pdb->fpdb = NULL;
        }

        if (pdb->latoms_p) {
            my_free(pdb->latoms_p);
            pdb->latoms_p = NULL;
        }

        my_free(pdb);
    }
}
