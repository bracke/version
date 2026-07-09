pragma Warnings (Off);
pragma Ada_95;
pragma Source_File_Name (ada_main, Spec_File_Name => "b__bench_status.ads");
pragma Source_File_Name (ada_main, Body_File_Name => "b__bench_status.adb");
pragma Suppress (Overflow_Check);
with Ada.Exceptions;

package body ada_main is

   E075 : Short_Integer; pragma Import (Ada, E075, "system__os_lib_E");
   E008 : Short_Integer; pragma Import (Ada, E008, "ada__exceptions_E");
   E013 : Short_Integer; pragma Import (Ada, E013, "system__soft_links_E");
   E024 : Short_Integer; pragma Import (Ada, E024, "system__exception_table_E");
   E040 : Short_Integer; pragma Import (Ada, E040, "ada__containers_E");
   E070 : Short_Integer; pragma Import (Ada, E070, "ada__io_exceptions_E");
   E031 : Short_Integer; pragma Import (Ada, E031, "ada__numerics_E");
   E055 : Short_Integer; pragma Import (Ada, E055, "ada__strings_E");
   E057 : Short_Integer; pragma Import (Ada, E057, "ada__strings__maps_E");
   E060 : Short_Integer; pragma Import (Ada, E060, "ada__strings__maps__constants_E");
   E045 : Short_Integer; pragma Import (Ada, E045, "interfaces__c_E");
   E025 : Short_Integer; pragma Import (Ada, E025, "system__exceptions_E");
   E086 : Short_Integer; pragma Import (Ada, E086, "system__object_reader_E");
   E050 : Short_Integer; pragma Import (Ada, E050, "system__dwarf_lines_E");
   E020 : Short_Integer; pragma Import (Ada, E020, "system__soft_links__initialize_E");
   E039 : Short_Integer; pragma Import (Ada, E039, "system__traceback__symbolic_E");
   E195 : Short_Integer; pragma Import (Ada, E195, "ada__assertions_E");
   E127 : Short_Integer; pragma Import (Ada, E127, "ada__strings__utf_encoding_E");
   E135 : Short_Integer; pragma Import (Ada, E135, "ada__tags_E");
   E125 : Short_Integer; pragma Import (Ada, E125, "ada__strings__text_buffers_E");
   E210 : Short_Integer; pragma Import (Ada, E210, "gnat_E");
   E223 : Short_Integer; pragma Import (Ada, E223, "interfaces__c__strings_E");
   E123 : Short_Integer; pragma Import (Ada, E123, "ada__streams_E");
   E175 : Short_Integer; pragma Import (Ada, E175, "system__file_control_block_E");
   E145 : Short_Integer; pragma Import (Ada, E145, "system__finalization_root_E");
   E121 : Short_Integer; pragma Import (Ada, E121, "ada__finalization_E");
   E172 : Short_Integer; pragma Import (Ada, E172, "system__file_io_E");
   E205 : Short_Integer; pragma Import (Ada, E205, "ada__streams__stream_io_E");
   E179 : Short_Integer; pragma Import (Ada, E179, "system__storage_pools_E");
   E197 : Short_Integer; pragma Import (Ada, E197, "system__storage_pools__subpools_E");
   E157 : Short_Integer; pragma Import (Ada, E157, "ada__strings__unbounded_E");
   E304 : Short_Integer; pragma Import (Ada, E304, "system__task_info_E");
   E424 : Short_Integer; pragma Import (Ada, E424, "system__regpat_E");
   E006 : Short_Integer; pragma Import (Ada, E006, "ada__calendar_E");
   E406 : Short_Integer; pragma Import (Ada, E406, "ada__calendar__delays_E");
   E113 : Short_Integer; pragma Import (Ada, E113, "ada__calendar__time_zones_E");
   E181 : Short_Integer; pragma Import (Ada, E181, "ada__text_io_E");
   E444 : Short_Integer; pragma Import (Ada, E444, "gnat__secure_hashes_E");
   E451 : Short_Integer; pragma Import (Ada, E451, "gnat__secure_hashes__sha2_common_E");
   E446 : Short_Integer; pragma Import (Ada, E446, "gnat__secure_hashes__sha2_32_E");
   E442 : Short_Integer; pragma Import (Ada, E442, "gnat__sha256_E");
   E298 : Short_Integer; pragma Import (Ada, E298, "system__task_primitives__operations_E");
   E225 : Short_Integer; pragma Import (Ada, E225, "system__pool_global_E");
   E419 : Short_Integer; pragma Import (Ada, E419, "gnat__expect_E");
   E399 : Short_Integer; pragma Import (Ada, E399, "gnat__sockets_E");
   E402 : Short_Integer; pragma Import (Ada, E402, "gnat__sockets__poll_E");
   E411 : Short_Integer; pragma Import (Ada, E411, "gnat__sockets__thin_common_E");
   E404 : Short_Integer; pragma Import (Ada, E404, "gnat__sockets__thin_E");
   E177 : Short_Integer; pragma Import (Ada, E177, "system__regexp_E");
   E109 : Short_Integer; pragma Import (Ada, E109, "ada__directories_E");
   E344 : Short_Integer; pragma Import (Ada, E344, "system__tasking__protected_objects_E");
   E342 : Short_Integer; pragma Import (Ada, E342, "http_client__cancellation_E");
   E326 : Short_Integer; pragma Import (Ada, E326, "http_client__headers_E");
   E328 : Short_Integer; pragma Import (Ada, E328, "http_client__http2_E");
   E368 : Short_Integer; pragma Import (Ada, E368, "http_client__http2__frames_E");
   E370 : Short_Integer; pragma Import (Ada, E370, "http_client__http2__hpack_E");
   E374 : Short_Integer; pragma Import (Ada, E374, "http_client__http2__settings_E");
   E380 : Short_Integer; pragma Import (Ada, E380, "http_client__quic_E");
   E378 : Short_Integer; pragma Import (Ada, E378, "http_client__http3_E");
   E332 : Short_Integer; pragma Import (Ada, E332, "http_client__request_bodies_E");
   E376 : Short_Integer; pragma Import (Ada, E376, "http_client__http2_execution_common_E");
   E360 : Short_Integer; pragma Import (Ada, E360, "http_client__resources_E");
   E358 : Short_Integer; pragma Import (Ada, E358, "http_client__diagnostics_E");
   E354 : Short_Integer; pragma Import (Ada, E354, "http_client__responses_E");
   E390 : Short_Integer; pragma Import (Ada, E390, "http_client__transports_E");
   E335 : Short_Integer; pragma Import (Ada, E335, "http_client__uri_E");
   E350 : Short_Integer; pragma Import (Ada, E350, "http_client__cookies_E");
   E386 : Short_Integer; pragma Import (Ada, E386, "http_client__proxies_E");
   E415 : Short_Integer; pragma Import (Ada, E415, "http_client__proxies__socks_E");
   E330 : Short_Integer; pragma Import (Ada, E330, "http_client__requests_E");
   E366 : Short_Integer; pragma Import (Ada, E366, "http_client__http1_E");
   E372 : Short_Integer; pragma Import (Ada, E372, "http_client__http2__mapping_E");
   E384 : Short_Integer; pragma Import (Ada, E384, "http_client__http3__mapping_E");
   E382 : Short_Integer; pragma Import (Ada, E382, "http_client__http3__execution_E");
   E395 : Short_Integer; pragma Import (Ada, E395, "http_client__tls__client_certificates_E");
   E397 : Short_Integer; pragma Import (Ada, E397, "http_client__transports__tcp_E");
   E413 : Short_Integer; pragma Import (Ada, E413, "http_client__transports__socks_E");
   E392 : Short_Integer; pragma Import (Ada, E392, "http_client__transports__tls_E");
   E235 : Short_Integer; pragma Import (Ada, E235, "version__availability_E");
   E282 : Short_Integer; pragma Import (Ada, E282, "version__hash_E");
   E217 : Short_Integer; pragma Import (Ada, E217, "version__path_safety_E");
   E317 : Short_Integer; pragma Import (Ada, E317, "version__pkt_line_E");
   E219 : Short_Integer; pragma Import (Ada, E219, "version__platform_E");
   E203 : Short_Integer; pragma Import (Ada, E203, "version__files_E");
   E209 : Short_Integer; pragma Import (Ada, E209, "version__files__internal_E");
   E213 : Short_Integer; pragma Import (Ada, E213, "version__files__rollback_E");
   E215 : Short_Integer; pragma Import (Ada, E215, "version__filesystem_guard_E");
   E502 : Short_Integer; pragma Import (Ada, E502, "version__init_E");
   E248 : Short_Integer; pragma Import (Ada, E248, "version__ref_names_E");
   E240 : Short_Integer; pragma Import (Ada, E240, "version__transport_E");
   E242 : Short_Integer; pragma Import (Ada, E242, "version__transport__local_E");
   E417 : Short_Integer; pragma Import (Ada, E417, "version__transport__ssh_E");
   E237 : Short_Integer; pragma Import (Ada, E237, "version__repository_format_E");
   E233 : Short_Integer; pragma Import (Ada, E233, "version__repository_E");
   E231 : Short_Integer; pragma Import (Ada, E231, "version__config_E");
   E504 : Short_Integer; pragma Import (Ada, E504, "version__gitmodules_E");
   E455 : Short_Integer; pragma Import (Ada, E455, "version__hooks_E");
   E468 : Short_Integer; pragma Import (Ada, E468, "version__pathspec_E");
   E466 : Short_Integer; pragma Import (Ada, E466, "version__sparse_E");
   E254 : Short_Integer; pragma Import (Ada, E254, "zlib_E");
   E256 : Short_Integer; pragma Import (Ada, E256, "zlib__bit_writer_E");
   E264 : Short_Integer; pragma Import (Ada, E264, "zlib__bits_E");
   E270 : Short_Integer; pragma Import (Ada, E270, "zlib__checksums_E");
   E276 : Short_Integer; pragma Import (Ada, E276, "zlib__crc32_internal_E");
   E268 : Short_Integer; pragma Import (Ada, E268, "zlib__fixed_compress_E");
   E274 : Short_Integer; pragma Import (Ada, E274, "zlib__huffman_builder_E");
   E272 : Short_Integer; pragma Import (Ada, E272, "zlib__lz77_matcher_E");
   E258 : Short_Integer; pragma Import (Ada, E258, "zlib__block_chooser_E");
   E278 : Short_Integer; pragma Import (Ada, E278, "zlib__sliding_window_E");
   E266 : Short_Integer; pragma Import (Ada, E266, "zlib__stream_bits_E");
   E262 : Short_Integer; pragma Import (Ada, E262, "zlib__huffman_E");
   E260 : Short_Integer; pragma Import (Ada, E260, "zlib__deflate_tables_E");
   E280 : Short_Integer; pragma Import (Ada, E280, "zlib__stream_inflate_E");
   E356 : Short_Integer; pragma Import (Ada, E356, "http_client__zlib_decompression_E");
   E352 : Short_Integer; pragma Import (Ada, E352, "http_client__decompression_E");
   E340 : Short_Integer; pragma Import (Ada, E340, "http_client__response_streams_E");
   E388 : Short_Integer; pragma Import (Ada, E388, "http_client__response_streams__http2_io_E");
   E252 : Short_Integer; pragma Import (Ada, E252, "version__compression_E");
   E440 : Short_Integer; pragma Import (Ada, E440, "version__lfs_E");
   E321 : Short_Integer; pragma Import (Ada, E321, "version__transport__http_E");
   E250 : Short_Integer; pragma Import (Ada, E250, "version__objects_E");
   E290 : Short_Integer; pragma Import (Ada, E290, "version__fetch_E");
   E284 : Short_Integer; pragma Import (Ada, E284, "version__pack_E");
   E286 : Short_Integer; pragma Import (Ada, E286, "version__pack_index_E");
   E246 : Short_Integer; pragma Import (Ada, E246, "version__packed_refs_E");
   E288 : Short_Integer; pragma Import (Ada, E288, "version__promisor_E");
   E315 : Short_Integer; pragma Import (Ada, E315, "version__ref_transaction_E");
   E313 : Short_Integer; pragma Import (Ada, E313, "version__fetch__internal_E");
   E244 : Short_Integer; pragma Import (Ada, E244, "version__refs_E");
   E319 : Short_Integer; pragma Import (Ada, E319, "version__shallow_E");
   E428 : Short_Integer; pragma Import (Ada, E428, "version__upload_pack_E");
   E486 : Short_Integer; pragma Import (Ada, E486, "version__cherry_pick_state_E");
   E229 : Short_Integer; pragma Import (Ada, E229, "version__ignore_E");
   E436 : Short_Integer; pragma Import (Ada, E436, "version__pack_index_cache_E");
   E434 : Short_Integer; pragma Import (Ada, E434, "version__object_cache_E");
   E488 : Short_Integer; pragma Import (Ada, E488, "version__rebase_state_E");
   E464 : Short_Integer; pragma Import (Ada, E464, "version__ref_cache_E");
   E458 : Short_Integer; pragma Import (Ada, E458, "version__reflog_E");
   E472 : Short_Integer; pragma Import (Ada, E472, "version__remotes_E");
   E474 : Short_Integer; pragma Import (Ada, E474, "version__remotes__test_hooks_E");
   E494 : Short_Integer; pragma Import (Ada, E494, "version__revert_state_E");
   E492 : Short_Integer; pragma Import (Ada, E492, "version__revisions_E");
   E438 : Short_Integer; pragma Import (Ada, E438, "version__shallow_cache_E");
   E432 : Short_Integer; pragma Import (Ada, E432, "version__history_E");
   E460 : Short_Integer; pragma Import (Ada, E460, "version__staging_E");
   E470 : Short_Integer; pragma Import (Ada, E470, "version__tracking_E");
   E476 : Short_Integer; pragma Import (Ada, E476, "version__tree_cache_E");
   E490 : Short_Integer; pragma Import (Ada, E490, "version__restore_E");
   E453 : Short_Integer; pragma Import (Ada, E453, "version__write_E");
   E430 : Short_Integer; pragma Import (Ada, E430, "version__merge_E");
   E462 : Short_Integer; pragma Import (Ada, E462, "version__merge_state_E");
   E484 : Short_Integer; pragma Import (Ada, E484, "version__branch_E");
   E482 : Short_Integer; pragma Import (Ada, E482, "version__clone_E");
   E498 : Short_Integer; pragma Import (Ada, E498, "version__diff_E");
   E496 : Short_Integer; pragma Import (Ada, E496, "version__stash_E");
   E190 : Short_Integer; pragma Import (Ada, E190, "version__status_E");
   E480 : Short_Integer; pragma Import (Ada, E480, "version__submodules_E");
   E478 : Short_Integer; pragma Import (Ada, E478, "version__working_tree_E");
   E500 : Short_Integer; pragma Import (Ada, E500, "version__worktrees_E");

   Sec_Default_Sized_Stacks : array (1 .. 1) of aliased System.Secondary_Stack.SS_Stack (System.Parameters.Runtime_Default_Sec_Stack_Size);

   Local_Priority_Specific_Dispatching : constant String := "";
   Local_Interrupt_States : constant String := "";

   Is_Elaborated : Boolean := False;

   procedure finalize_library is
   begin
      declare
         procedure F1;
         pragma Import (Ada, F1, "version__branch__finalize_body");
      begin
         E484 := E484 - 1;
         F1;
      end;
      E500 := E500 - 1;
      declare
         procedure F2;
         pragma Import (Ada, F2, "version__worktrees__finalize_spec");
      begin
         F2;
      end;
      declare
         procedure F3;
         pragma Import (Ada, F3, "version__status__finalize_body");
      begin
         E190 := E190 - 1;
         F3;
      end;
      declare
         procedure F4;
         pragma Import (Ada, F4, "version__stash__finalize_body");
      begin
         E496 := E496 - 1;
         F4;
      end;
      declare
         procedure F5;
         pragma Import (Ada, F5, "version__diff__finalize_body");
      begin
         E498 := E498 - 1;
         F5;
      end;
      declare
         procedure F6;
         pragma Import (Ada, F6, "version__working_tree__finalize_body");
      begin
         E478 := E478 - 1;
         F6;
      end;
      declare
         procedure F7;
         pragma Import (Ada, F7, "version__working_tree__finalize_spec");
      begin
         F7;
      end;
      E480 := E480 - 1;
      declare
         procedure F8;
         pragma Import (Ada, F8, "version__submodules__finalize_spec");
      begin
         F8;
      end;
      declare
         procedure F9;
         pragma Import (Ada, F9, "version__status__finalize_spec");
      begin
         F9;
      end;
      declare
         procedure F10;
         pragma Import (Ada, F10, "version__stash__finalize_spec");
      begin
         F10;
      end;
      declare
         procedure F11;
         pragma Import (Ada, F11, "version__clone__finalize_body");
      begin
         E482 := E482 - 1;
         F11;
      end;
      declare
         procedure F12;
         pragma Import (Ada, F12, "version__branch__finalize_spec");
      begin
         F12;
      end;
      declare
         procedure F13;
         pragma Import (Ada, F13, "version__merge__finalize_body");
      begin
         E430 := E430 - 1;
         F13;
      end;
      declare
         procedure F14;
         pragma Import (Ada, F14, "version__merge__finalize_spec");
      begin
         F14;
      end;
      declare
         procedure F15;
         pragma Import (Ada, F15, "version__write__finalize_body");
      begin
         E453 := E453 - 1;
         F15;
      end;
      declare
         procedure F16;
         pragma Import (Ada, F16, "version__restore__finalize_body");
      begin
         E490 := E490 - 1;
         F16;
      end;
      E476 := E476 - 1;
      declare
         procedure F17;
         pragma Import (Ada, F17, "version__tree_cache__finalize_spec");
      begin
         F17;
      end;
      declare
         procedure F18;
         pragma Import (Ada, F18, "version__tracking__finalize_body");
      begin
         E470 := E470 - 1;
         F18;
      end;
      E460 := E460 - 1;
      declare
         procedure F19;
         pragma Import (Ada, F19, "version__staging__finalize_spec");
      begin
         F19;
      end;
      declare
         procedure F20;
         pragma Import (Ada, F20, "version__history__finalize_body");
      begin
         E432 := E432 - 1;
         F20;
      end;
      declare
         procedure F21;
         pragma Import (Ada, F21, "version__history__finalize_spec");
      begin
         F21;
      end;
      E494 := E494 - 1;
      declare
         procedure F22;
         pragma Import (Ada, F22, "version__revert_state__finalize_spec");
      begin
         F22;
      end;
      declare
         procedure F23;
         pragma Import (Ada, F23, "version__remotes__finalize_body");
      begin
         E472 := E472 - 1;
         F23;
      end;
      declare
         procedure F24;
         pragma Import (Ada, F24, "version__remotes__finalize_spec");
      begin
         F24;
      end;
      E464 := E464 - 1;
      declare
         procedure F25;
         pragma Import (Ada, F25, "version__ref_cache__finalize_spec");
      begin
         F25;
      end;
      E488 := E488 - 1;
      declare
         procedure F26;
         pragma Import (Ada, F26, "version__rebase_state__finalize_spec");
      begin
         F26;
      end;
      E434 := E434 - 1;
      declare
         procedure F27;
         pragma Import (Ada, F27, "version__object_cache__finalize_spec");
      begin
         F27;
      end;
      declare
         procedure F28;
         pragma Import (Ada, F28, "version__pack_index_cache__finalize_body");
      begin
         E436 := E436 - 1;
         F28;
      end;
      declare
         procedure F29;
         pragma Import (Ada, F29, "version__pack_index_cache__finalize_spec");
      begin
         F29;
      end;
      declare
         procedure F30;
         pragma Import (Ada, F30, "version__ignore__finalize_body");
      begin
         E229 := E229 - 1;
         F30;
      end;
      declare
         procedure F31;
         pragma Import (Ada, F31, "version__ignore__finalize_spec");
      begin
         F31;
      end;
      E486 := E486 - 1;
      declare
         procedure F32;
         pragma Import (Ada, F32, "version__cherry_pick_state__finalize_spec");
      begin
         F32;
      end;
      declare
         procedure F33;
         pragma Import (Ada, F33, "version__fetch__finalize_body");
      begin
         E290 := E290 - 1;
         F33;
      end;
      E428 := E428 - 1;
      declare
         procedure F34;
         pragma Import (Ada, F34, "version__upload_pack__finalize_spec");
      begin
         F34;
      end;
      declare
         procedure F35;
         pragma Import (Ada, F35, "version__shallow__finalize_body");
      begin
         E319 := E319 - 1;
         F35;
      end;
      E315 := E315 - 1;
      E244 := E244 - 1;
      declare
         procedure F36;
         pragma Import (Ada, F36, "version__refs__finalize_spec");
      begin
         F36;
      end;
      declare
         procedure F37;
         pragma Import (Ada, F37, "version__ref_transaction__finalize_spec");
      begin
         F37;
      end;
      E250 := E250 - 1;
      E246 := E246 - 1;
      declare
         procedure F38;
         pragma Import (Ada, F38, "version__packed_refs__finalize_spec");
      begin
         F38;
      end;
      declare
         procedure F39;
         pragma Import (Ada, F39, "version__pack__finalize_body");
      begin
         E284 := E284 - 1;
         F39;
      end;
      E286 := E286 - 1;
      declare
         procedure F40;
         pragma Import (Ada, F40, "version__pack_index__finalize_spec");
      begin
         F40;
      end;
      declare
         procedure F41;
         pragma Import (Ada, F41, "version__objects__finalize_spec");
      begin
         F41;
      end;
      E340 := E340 - 1;
      declare
         procedure F42;
         pragma Import (Ada, F42, "http_client__response_streams__finalize_spec");
      begin
         F42;
      end;
      declare
         procedure F43;
         pragma Import (Ada, F43, "zlib__finalize_body");
      begin
         E254 := E254 - 1;
         F43;
      end;
      E264 := E264 - 1;
      declare
         procedure F44;
         pragma Import (Ada, F44, "zlib__bits__finalize_spec");
      begin
         F44;
      end;
      E256 := E256 - 1;
      declare
         procedure F45;
         pragma Import (Ada, F45, "zlib__bit_writer__finalize_spec");
      begin
         F45;
      end;
      E466 := E466 - 1;
      declare
         procedure F46;
         pragma Import (Ada, F46, "version__sparse__finalize_spec");
      begin
         F46;
      end;
      E468 := E468 - 1;
      declare
         procedure F47;
         pragma Import (Ada, F47, "version__pathspec__finalize_spec");
      begin
         F47;
      end;
      E455 := E455 - 1;
      declare
         procedure F48;
         pragma Import (Ada, F48, "version__hooks__finalize_spec");
      begin
         F48;
      end;
      E504 := E504 - 1;
      declare
         procedure F49;
         pragma Import (Ada, F49, "version__gitmodules__finalize_spec");
      begin
         F49;
      end;
      E231 := E231 - 1;
      declare
         procedure F50;
         pragma Import (Ada, F50, "version__config__finalize_spec");
      begin
         F50;
      end;
      declare
         procedure F51;
         pragma Import (Ada, F51, "version__transport__local__finalize_body");
      begin
         E242 := E242 - 1;
         F51;
      end;
      declare
         procedure F52;
         pragma Import (Ada, F52, "version__transport__local__finalize_spec");
      begin
         F52;
      end;
      E215 := E215 - 1;
      declare
         procedure F53;
         pragma Import (Ada, F53, "version__filesystem_guard__finalize_spec");
      begin
         F53;
      end;
      E317 := E317 - 1;
      declare
         procedure F54;
         pragma Import (Ada, F54, "version__pkt_line__finalize_spec");
      begin
         F54;
      end;
      E217 := E217 - 1;
      declare
         procedure F55;
         pragma Import (Ada, F55, "version__path_safety__finalize_spec");
      begin
         F55;
      end;
      E392 := E392 - 1;
      declare
         procedure F56;
         pragma Import (Ada, F56, "http_client__transports__tls__finalize_spec");
      begin
         F56;
      end;
      E397 := E397 - 1;
      declare
         procedure F57;
         pragma Import (Ada, F57, "http_client__transports__tcp__finalize_spec");
      begin
         F57;
      end;
      E350 := E350 - 1;
      declare
         procedure F58;
         pragma Import (Ada, F58, "http_client__cookies__finalize_spec");
      begin
         F58;
      end;
      declare
         procedure F59;
         pragma Import (Ada, F59, "http_client__uri__finalize_body");
      begin
         E335 := E335 - 1;
         F59;
      end;
      E358 := E358 - 1;
      declare
         procedure F60;
         pragma Import (Ada, F60, "http_client__diagnostics__finalize_spec");
      begin
         F60;
      end;
      E332 := E332 - 1;
      declare
         procedure F61;
         pragma Import (Ada, F61, "http_client__request_bodies__finalize_spec");
      begin
         F61;
      end;
      E380 := E380 - 1;
      declare
         procedure F62;
         pragma Import (Ada, F62, "http_client__quic__finalize_spec");
      begin
         F62;
      end;
      E326 := E326 - 1;
      declare
         procedure F63;
         pragma Import (Ada, F63, "http_client__headers__finalize_spec");
      begin
         F63;
      end;
      declare
         procedure F64;
         pragma Import (Ada, F64, "ada__directories__finalize_body");
      begin
         E109 := E109 - 1;
         F64;
      end;
      declare
         procedure F65;
         pragma Import (Ada, F65, "ada__directories__finalize_spec");
      begin
         F65;
      end;
      E177 := E177 - 1;
      declare
         procedure F66;
         pragma Import (Ada, F66, "system__regexp__finalize_spec");
      begin
         F66;
      end;
      declare
         procedure F67;
         pragma Import (Ada, F67, "gnat__sockets__finalize_body");
      begin
         E399 := E399 - 1;
         F67;
      end;
      declare
         procedure F68;
         pragma Import (Ada, F68, "gnat__sockets__finalize_spec");
      begin
         F68;
      end;
      E419 := E419 - 1;
      declare
         procedure F69;
         pragma Import (Ada, F69, "gnat__expect__finalize_spec");
      begin
         F69;
      end;
      E225 := E225 - 1;
      declare
         procedure F70;
         pragma Import (Ada, F70, "system__pool_global__finalize_spec");
      begin
         F70;
      end;
      E442 := E442 - 1;
      declare
         procedure F71;
         pragma Import (Ada, F71, "gnat__sha256__finalize_spec");
      begin
         F71;
      end;
      E181 := E181 - 1;
      declare
         procedure F72;
         pragma Import (Ada, F72, "ada__text_io__finalize_spec");
      begin
         F72;
      end;
      E157 := E157 - 1;
      declare
         procedure F73;
         pragma Import (Ada, F73, "ada__strings__unbounded__finalize_spec");
      begin
         F73;
      end;
      E197 := E197 - 1;
      declare
         procedure F74;
         pragma Import (Ada, F74, "system__storage_pools__subpools__finalize_spec");
      begin
         F74;
      end;
      E205 := E205 - 1;
      declare
         procedure F75;
         pragma Import (Ada, F75, "ada__streams__stream_io__finalize_spec");
      begin
         F75;
      end;
      declare
         procedure F76;
         pragma Import (Ada, F76, "system__file_io__finalize_body");
      begin
         E172 := E172 - 1;
         F76;
      end;
      declare
         procedure Reraise_Library_Exception_If_Any;
            pragma Import (Ada, Reraise_Library_Exception_If_Any, "__gnat_reraise_library_exception_if_any");
      begin
         Reraise_Library_Exception_If_Any;
      end;
   end finalize_library;

   procedure adafinal is
      procedure s_stalib_adafinal;
      pragma Import (Ada, s_stalib_adafinal, "system__standard_library__adafinal");

      procedure Runtime_Finalize;
      pragma Import (C, Runtime_Finalize, "__gnat_runtime_finalize");

   begin
      if not Is_Elaborated then
         return;
      end if;
      Is_Elaborated := False;
      Runtime_Finalize;
      s_stalib_adafinal;
   end adafinal;

   type No_Param_Proc is access procedure;
   pragma Favor_Top_Level (No_Param_Proc);

   procedure adainit is
      Main_Priority : Integer;
      pragma Import (C, Main_Priority, "__gl_main_priority");
      Time_Slice_Value : Integer;
      pragma Import (C, Time_Slice_Value, "__gl_time_slice_val");
      WC_Encoding : Character;
      pragma Import (C, WC_Encoding, "__gl_wc_encoding");
      Locking_Policy : Character;
      pragma Import (C, Locking_Policy, "__gl_locking_policy");
      Queuing_Policy : Character;
      pragma Import (C, Queuing_Policy, "__gl_queuing_policy");
      Task_Dispatching_Policy : Character;
      pragma Import (C, Task_Dispatching_Policy, "__gl_task_dispatching_policy");
      Priority_Specific_Dispatching : System.Address;
      pragma Import (C, Priority_Specific_Dispatching, "__gl_priority_specific_dispatching");
      Num_Specific_Dispatching : Integer;
      pragma Import (C, Num_Specific_Dispatching, "__gl_num_specific_dispatching");
      Main_CPU : Integer;
      pragma Import (C, Main_CPU, "__gl_main_cpu");
      Interrupt_States : System.Address;
      pragma Import (C, Interrupt_States, "__gl_interrupt_states");
      Num_Interrupt_States : Integer;
      pragma Import (C, Num_Interrupt_States, "__gl_num_interrupt_states");
      Unreserve_All_Interrupts : Integer;
      pragma Import (C, Unreserve_All_Interrupts, "__gl_unreserve_all_interrupts");
      Detect_Blocking : Integer;
      pragma Import (C, Detect_Blocking, "__gl_detect_blocking");
      Default_Stack_Size : Integer;
      pragma Import (C, Default_Stack_Size, "__gl_default_stack_size");
      Default_Secondary_Stack_Size : System.Parameters.Size_Type;
      pragma Import (C, Default_Secondary_Stack_Size, "__gnat_default_ss_size");
      Bind_Env_Addr : System.Address;
      pragma Import (C, Bind_Env_Addr, "__gl_bind_env_addr");
      Interrupts_Default_To_System : Integer;
      pragma Import (C, Interrupts_Default_To_System, "__gl_interrupts_default_to_system");

      procedure Runtime_Initialize (Install_Handler : Integer);
      pragma Import (C, Runtime_Initialize, "__gnat_runtime_initialize");

      procedure Tasking_Runtime_Initialize;
      pragma Import (C, Tasking_Runtime_Initialize, "__gnat_tasking_runtime_initialize");

      Finalize_Library_Objects : No_Param_Proc;
      pragma Import (C, Finalize_Library_Objects, "__gnat_finalize_library_objects");
      Binder_Sec_Stacks_Count : Natural;
      pragma Import (Ada, Binder_Sec_Stacks_Count, "__gnat_binder_ss_count");
      Default_Sized_SS_Pool : System.Address;
      pragma Import (Ada, Default_Sized_SS_Pool, "__gnat_default_ss_pool");

   begin
      if Is_Elaborated then
         return;
      end if;
      Is_Elaborated := True;
      Main_Priority := -1;
      Time_Slice_Value := -1;
      WC_Encoding := 'b';
      Locking_Policy := ' ';
      Queuing_Policy := ' ';
      Task_Dispatching_Policy := ' ';
      Priority_Specific_Dispatching :=
        Local_Priority_Specific_Dispatching'Address;
      Num_Specific_Dispatching := 0;
      Main_CPU := -1;
      Interrupt_States := Local_Interrupt_States'Address;
      Num_Interrupt_States := 0;
      Unreserve_All_Interrupts := 0;
      Detect_Blocking := 0;
      Default_Stack_Size := -1;

      ada_main'Elab_Body;
      Default_Secondary_Stack_Size := System.Parameters.Runtime_Default_Sec_Stack_Size;
      Binder_Sec_Stacks_Count := 1;
      Default_Sized_SS_Pool := Sec_Default_Sized_Stacks'Address;

      Runtime_Initialize (1);
      Tasking_Runtime_Initialize;

      Finalize_Library_Objects := finalize_library'access;

      if E008 = 0 then
         Ada.Exceptions'Elab_Spec;
      end if;
      if E013 = 0 then
         System.Soft_Links'Elab_Spec;
      end if;
      if E024 = 0 then
         System.Exception_Table'Elab_Body;
      end if;
      E024 := E024 + 1;
      if E040 = 0 then
         Ada.Containers'Elab_Spec;
      end if;
      E040 := E040 + 1;
      if E070 = 0 then
         Ada.Io_Exceptions'Elab_Spec;
      end if;
      E070 := E070 + 1;
      if E031 = 0 then
         Ada.Numerics'Elab_Spec;
      end if;
      E031 := E031 + 1;
      if E055 = 0 then
         Ada.Strings'Elab_Spec;
      end if;
      E055 := E055 + 1;
      if E057 = 0 then
         Ada.Strings.Maps'Elab_Spec;
      end if;
      E057 := E057 + 1;
      if E060 = 0 then
         Ada.Strings.Maps.Constants'Elab_Spec;
      end if;
      E060 := E060 + 1;
      if E045 = 0 then
         Interfaces.C'Elab_Spec;
      end if;
      E045 := E045 + 1;
      if E025 = 0 then
         System.Exceptions'Elab_Spec;
      end if;
      E025 := E025 + 1;
      if E086 = 0 then
         System.Object_Reader'Elab_Spec;
      end if;
      E086 := E086 + 1;
      if E050 = 0 then
         System.Dwarf_Lines'Elab_Spec;
      end if;
      E050 := E050 + 1;
      if E075 = 0 then
         System.Os_Lib'Elab_Body;
      end if;
      E075 := E075 + 1;
      if E020 = 0 then
         System.Soft_Links.Initialize'Elab_Body;
      end if;
      E020 := E020 + 1;
      E013 := E013 + 1;
      if E039 = 0 then
         System.Traceback.Symbolic'Elab_Body;
      end if;
      E039 := E039 + 1;
      E008 := E008 + 1;
      if E195 = 0 then
         Ada.Assertions'Elab_Spec;
      end if;
      E195 := E195 + 1;
      if E127 = 0 then
         Ada.Strings.Utf_Encoding'Elab_Spec;
      end if;
      E127 := E127 + 1;
      if E135 = 0 then
         Ada.Tags'Elab_Spec;
      end if;
      if E135 = 0 then
         Ada.Tags'Elab_Body;
      end if;
      E135 := E135 + 1;
      if E125 = 0 then
         Ada.Strings.Text_Buffers'Elab_Spec;
      end if;
      E125 := E125 + 1;
      if E210 = 0 then
         Gnat'Elab_Spec;
      end if;
      E210 := E210 + 1;
      if E223 = 0 then
         Interfaces.C.Strings'Elab_Spec;
      end if;
      E223 := E223 + 1;
      if E123 = 0 then
         Ada.Streams'Elab_Spec;
      end if;
      E123 := E123 + 1;
      if E175 = 0 then
         System.File_Control_Block'Elab_Spec;
      end if;
      E175 := E175 + 1;
      if E145 = 0 then
         System.Finalization_Root'Elab_Spec;
      end if;
      E145 := E145 + 1;
      if E121 = 0 then
         Ada.Finalization'Elab_Spec;
      end if;
      E121 := E121 + 1;
      if E172 = 0 then
         System.File_Io'Elab_Body;
      end if;
      E172 := E172 + 1;
      if E205 = 0 then
         Ada.Streams.Stream_Io'Elab_Spec;
      end if;
      E205 := E205 + 1;
      if E179 = 0 then
         System.Storage_Pools'Elab_Spec;
      end if;
      E179 := E179 + 1;
      if E197 = 0 then
         System.Storage_Pools.Subpools'Elab_Spec;
      end if;
      E197 := E197 + 1;
      if E157 = 0 then
         Ada.Strings.Unbounded'Elab_Spec;
      end if;
      E157 := E157 + 1;
      if E304 = 0 then
         System.Task_Info'Elab_Spec;
      end if;
      E304 := E304 + 1;
      if E424 = 0 then
         System.Regpat'Elab_Spec;
      end if;
      E424 := E424 + 1;
      if E006 = 0 then
         Ada.Calendar'Elab_Spec;
      end if;
      if E006 = 0 then
         Ada.Calendar'Elab_Body;
      end if;
      E006 := E006 + 1;
      if E406 = 0 then
         Ada.Calendar.Delays'Elab_Body;
      end if;
      E406 := E406 + 1;
      if E113 = 0 then
         Ada.Calendar.Time_Zones'Elab_Spec;
      end if;
      E113 := E113 + 1;
      if E181 = 0 then
         Ada.Text_Io'Elab_Spec;
      end if;
      if E181 = 0 then
         Ada.Text_Io'Elab_Body;
      end if;
      E181 := E181 + 1;
      E444 := E444 + 1;
      E451 := E451 + 1;
      E446 := E446 + 1;
      if E442 = 0 then
         Gnat.Sha256'Elab_Spec;
      end if;
      E442 := E442 + 1;
      if E298 = 0 then
         System.Task_Primitives.Operations'Elab_Body;
      end if;
      E298 := E298 + 1;
      if E225 = 0 then
         System.Pool_Global'Elab_Spec;
      end if;
      E225 := E225 + 1;
      if E419 = 0 then
         Gnat.Expect'Elab_Spec;
      end if;
      E419 := E419 + 1;
      if E399 = 0 then
         Gnat.Sockets'Elab_Spec;
      end if;
      if E411 = 0 then
         Gnat.Sockets.Thin_Common'Elab_Spec;
      end if;
      E411 := E411 + 1;
      E404 := E404 + 1;
      if E399 = 0 then
         Gnat.Sockets'Elab_Body;
      end if;
      E399 := E399 + 1;
      E402 := E402 + 1;
      if E177 = 0 then
         System.Regexp'Elab_Spec;
      end if;
      E177 := E177 + 1;
      if E109 = 0 then
         Ada.Directories'Elab_Spec;
      end if;
      if E109 = 0 then
         Ada.Directories'Elab_Body;
      end if;
      E109 := E109 + 1;
      if E344 = 0 then
         System.Tasking.Protected_Objects'Elab_Body;
      end if;
      E344 := E344 + 1;
      E342 := E342 + 1;
      if E326 = 0 then
         Http_Client.Headers'Elab_Spec;
      end if;
      E326 := E326 + 1;
      E328 := E328 + 1;
      E368 := E368 + 1;
      E370 := E370 + 1;
      E374 := E374 + 1;
      if E380 = 0 then
         Http_Client.Quic'Elab_Spec;
      end if;
      if E380 = 0 then
         Http_Client.Quic'Elab_Body;
      end if;
      E380 := E380 + 1;
      E378 := E378 + 1;
      if E332 = 0 then
         Http_Client.Request_Bodies'Elab_Spec;
      end if;
      E332 := E332 + 1;
      E376 := E376 + 1;
      if E360 = 0 then
         Http_Client.Resources'Elab_Body;
      end if;
      E360 := E360 + 1;
      if E358 = 0 then
         Http_Client.Diagnostics'Elab_Spec;
      end if;
      if E358 = 0 then
         Http_Client.Diagnostics'Elab_Body;
      end if;
      E358 := E358 + 1;
      E354 := E354 + 1;
      E390 := E390 + 1;
      if E335 = 0 then
         Http_Client.Uri'Elab_Body;
      end if;
      E335 := E335 + 1;
      if E350 = 0 then
         Http_Client.Cookies'Elab_Spec;
      end if;
      E350 := E350 + 1;
      if E386 = 0 then
         Http_Client.Proxies'Elab_Spec;
      end if;
      E386 := E386 + 1;
      E415 := E415 + 1;
      E330 := E330 + 1;
      E366 := E366 + 1;
      E372 := E372 + 1;
      E384 := E384 + 1;
      E382 := E382 + 1;
      if E395 = 0 then
         Http_Client.Tls.Client_Certificates'Elab_Spec;
      end if;
      E395 := E395 + 1;
      if E397 = 0 then
         Http_Client.Transports.Tcp'Elab_Spec;
      end if;
      if E397 = 0 then
         Http_Client.Transports.Tcp'Elab_Body;
      end if;
      E397 := E397 + 1;
      E413 := E413 + 1;
      if E392 = 0 then
         Http_Client.Transports.Tls'Elab_Spec;
      end if;
      if E392 = 0 then
         Http_Client.Transports.Tls'Elab_Body;
      end if;
      E392 := E392 + 1;
      E235 := E235 + 1;
      E282 := E282 + 1;
      if E217 = 0 then
         Version.Path_Safety'Elab_Spec;
      end if;
      E217 := E217 + 1;
      if E317 = 0 then
         Version.Pkt_Line'Elab_Spec;
      end if;
      E317 := E317 + 1;
      E219 := E219 + 1;
      E209 := E209 + 1;
      E213 := E213 + 1;
      if E215 = 0 then
         Version.Filesystem_Guard'Elab_Spec;
      end if;
      E215 := E215 + 1;
      E203 := E203 + 1;
      E502 := E502 + 1;
      E248 := E248 + 1;
      E240 := E240 + 1;
      if E242 = 0 then
         Version.Transport.Local'Elab_Spec;
      end if;
      if E242 = 0 then
         Version.Transport.Local'Elab_Body;
      end if;
      E242 := E242 + 1;
      E417 := E417 + 1;
      E237 := E237 + 1;
      E233 := E233 + 1;
      if E231 = 0 then
         Version.Config'Elab_Spec;
      end if;
      E231 := E231 + 1;
      if E504 = 0 then
         Version.Gitmodules'Elab_Spec;
      end if;
      E504 := E504 + 1;
      if E455 = 0 then
         Version.Hooks'Elab_Spec;
      end if;
      E455 := E455 + 1;
      if E468 = 0 then
         Version.Pathspec'Elab_Spec;
      end if;
      E468 := E468 + 1;
      if E466 = 0 then
         Version.Sparse'Elab_Spec;
      end if;
      E466 := E466 + 1;
      if E254 = 0 then
         Zlib'Elab_Spec;
      end if;
      if E256 = 0 then
         Zlib.Bit_Writer'Elab_Spec;
      end if;
      E256 := E256 + 1;
      if E264 = 0 then
         Zlib.Bits'Elab_Spec;
      end if;
      E264 := E264 + 1;
      E270 := E270 + 1;
      if E276 = 0 then
         Zlib.Crc32_Internal'Elab_Body;
      end if;
      E276 := E276 + 1;
      E274 := E274 + 1;
      E278 := E278 + 1;
      E266 := E266 + 1;
      E262 := E262 + 1;
      E260 := E260 + 1;
      E258 := E258 + 1;
      E268 := E268 + 1;
      E272 := E272 + 1;
      E280 := E280 + 1;
      if E254 = 0 then
         Zlib'Elab_Body;
      end if;
      E254 := E254 + 1;
      E356 := E356 + 1;
      E352 := E352 + 1;
      if E340 = 0 then
         Http_Client.Response_Streams'Elab_Spec;
      end if;
      E388 := E388 + 1;
      if E340 = 0 then
         Http_Client.Response_Streams'Elab_Body;
      end if;
      E340 := E340 + 1;
      E252 := E252 + 1;
      E440 := E440 + 1;
      if E321 = 0 then
         Version.Transport.Http'Elab_Spec;
      end if;
      E321 := E321 + 1;
      if E250 = 0 then
         Version.Objects'Elab_Spec;
      end if;
      if E286 = 0 then
         Version.Pack_Index'Elab_Spec;
      end if;
      E286 := E286 + 1;
      if E284 = 0 then
         Version.Pack'Elab_Body;
      end if;
      E284 := E284 + 1;
      if E246 = 0 then
         Version.Packed_Refs'Elab_Spec;
      end if;
      E246 := E246 + 1;
      E288 := E288 + 1;
      E250 := E250 + 1;
      if E315 = 0 then
         Version.Ref_Transaction'Elab_Spec;
      end if;
      if E244 = 0 then
         Version.Refs'Elab_Spec;
      end if;
      E244 := E244 + 1;
      E313 := E313 + 1;
      E315 := E315 + 1;
      if E319 = 0 then
         Version.Shallow'Elab_Body;
      end if;
      E319 := E319 + 1;
      if E428 = 0 then
         Version.Upload_Pack'Elab_Spec;
      end if;
      E428 := E428 + 1;
      if E290 = 0 then
         Version.Fetch'Elab_Body;
      end if;
      E290 := E290 + 1;
      if E486 = 0 then
         Version.Cherry_Pick_State'Elab_Spec;
      end if;
      E486 := E486 + 1;
      if E229 = 0 then
         Version.Ignore'Elab_Spec;
      end if;
      if E229 = 0 then
         Version.Ignore'Elab_Body;
      end if;
      E229 := E229 + 1;
      if E436 = 0 then
         Version.Pack_Index_Cache'Elab_Spec;
      end if;
      if E436 = 0 then
         Version.Pack_Index_Cache'Elab_Body;
      end if;
      E436 := E436 + 1;
      if E434 = 0 then
         Version.Object_Cache'Elab_Spec;
      end if;
      E434 := E434 + 1;
      if E488 = 0 then
         Version.Rebase_State'Elab_Spec;
      end if;
      E488 := E488 + 1;
      if E464 = 0 then
         Version.Ref_Cache'Elab_Spec;
      end if;
      E464 := E464 + 1;
      E458 := E458 + 1;
      if E472 = 0 then
         Version.Remotes'Elab_Spec;
      end if;
      E474 := E474 + 1;
      if E472 = 0 then
         Version.Remotes'Elab_Body;
      end if;
      E472 := E472 + 1;
      if E494 = 0 then
         Version.Revert_State'Elab_Spec;
      end if;
      E494 := E494 + 1;
      E492 := E492 + 1;
      E438 := E438 + 1;
      if E432 = 0 then
         Version.History'Elab_Spec;
      end if;
      if E432 = 0 then
         Version.History'Elab_Body;
      end if;
      E432 := E432 + 1;
      if E460 = 0 then
         Version.Staging'Elab_Spec;
      end if;
      E460 := E460 + 1;
      if E470 = 0 then
         Version.Tracking'Elab_Body;
      end if;
      E470 := E470 + 1;
      if E476 = 0 then
         Version.Tree_Cache'Elab_Spec;
      end if;
      E476 := E476 + 1;
      if E490 = 0 then
         Version.Restore'Elab_Body;
      end if;
      E490 := E490 + 1;
      if E453 = 0 then
         Version.Write'Elab_Body;
      end if;
      E453 := E453 + 1;
      if E430 = 0 then
         Version.Merge'Elab_Spec;
      end if;
      if E430 = 0 then
         Version.Merge'Elab_Body;
      end if;
      E430 := E430 + 1;
      E462 := E462 + 1;
      if E484 = 0 then
         Version.Branch'Elab_Spec;
      end if;
      if E482 = 0 then
         Version.Clone'Elab_Body;
      end if;
      E482 := E482 + 1;
      if E496 = 0 then
         Version.Stash'Elab_Spec;
      end if;
      if E190 = 0 then
         Version.Status'Elab_Spec;
      end if;
      if E480 = 0 then
         Version.Submodules'Elab_Spec;
      end if;
      E480 := E480 + 1;
      if E478 = 0 then
         Version.Working_Tree'Elab_Spec;
      end if;
      if E478 = 0 then
         Version.Working_Tree'Elab_Body;
      end if;
      E478 := E478 + 1;
      if E498 = 0 then
         Version.Diff'Elab_Body;
      end if;
      E498 := E498 + 1;
      if E496 = 0 then
         Version.Stash'Elab_Body;
      end if;
      E496 := E496 + 1;
      if E190 = 0 then
         Version.Status'Elab_Body;
      end if;
      E190 := E190 + 1;
      if E500 = 0 then
         Version.Worktrees'Elab_Spec;
      end if;
      E500 := E500 + 1;
      if E484 = 0 then
         Version.Branch'Elab_Body;
      end if;
      E484 := E484 + 1;
   end adainit;

   procedure Ada_Main_Program;
   pragma Import (Ada, Ada_Main_Program, "_ada_bench_status");

   function main
     (argc : Integer;
      argv : System.Address;
      envp : System.Address)
      return Integer
   is
      procedure Initialize (Addr : System.Address);
      pragma Import (C, Initialize, "__gnat_initialize");

      procedure Finalize;
      pragma Import (C, Finalize, "__gnat_finalize");
      SEH : aliased array (1 .. 2) of Integer;

      Ensure_Reference : aliased System.Address := Ada_Main_Program_Name'Address;
      pragma Volatile (Ensure_Reference);

   begin
      if gnat_argc = 0 then
         gnat_argc := argc;
         gnat_argv := argv;
      end if;
      gnat_envp := envp;

      Initialize (SEH'Address);
      adainit;
      Ada_Main_Program;
      adafinal;
      Finalize;
      return (gnat_exit_status);
   end;

--  BEGIN Object file/option list
   --   /home/bent/Projekte/Ada/version/tools/obj/bench_status.o
   --   -L/home/bent/Projekte/Ada/version/tools/obj/
   --   -L/home/bent/Projekte/Ada/version/tools/obj/
   --   -L/home/bent/Projekte/Ada/version/obj/development/
   --   -L/home/bent/Projekte/Ada/project_tools/lib/
   --   -L/home/bent/Projekte/Ada/versionlib/lib/
   --   -L/home/bent/Projekte/Ada/ssh_lib_build/lib/
   --   -L/home/bent/Projekte/Ada/cryptolib/lib/
   --   -L/home/bent/Projekte/Ada/zlib/lib/
   --   -L/home/bent/Projekte/Ada/HttpClient/lib/
   --   -L/home/bent/Projekte/Ada/i18n/lib/
   --   -L/home/bent/.local/share/alire/toolchains/gnat_native_15.2.1_4640d4b3/lib/gcc/x86_64-pc-linux-gnu/15.2.0/adalib/
   --   -static
   --   -lbz2
   --   -lzstd
   --   -lgnarl
   --   -lgnat
   --   -lrt
   --   -lpthread
   --   -ldl
--  END Object file/option list   

end ada_main;
