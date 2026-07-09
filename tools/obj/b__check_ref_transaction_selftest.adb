pragma Warnings (Off);
pragma Ada_95;
pragma Source_File_Name (ada_main, Spec_File_Name => "b__check_ref_transaction_selftest.ads");
pragma Source_File_Name (ada_main, Body_File_Name => "b__check_ref_transaction_selftest.adb");
pragma Suppress (Overflow_Check);
with Ada.Exceptions;

package body ada_main is

   E075 : Short_Integer; pragma Import (Ada, E075, "system__os_lib_E");
   E011 : Short_Integer; pragma Import (Ada, E011, "ada__exceptions_E");
   E015 : Short_Integer; pragma Import (Ada, E015, "system__soft_links_E");
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
   E017 : Short_Integer; pragma Import (Ada, E017, "system__soft_links__initialize_E");
   E039 : Short_Integer; pragma Import (Ada, E039, "system__traceback__symbolic_E");
   E234 : Short_Integer; pragma Import (Ada, E234, "ada__assertions_E");
   E127 : Short_Integer; pragma Import (Ada, E127, "ada__strings__utf_encoding_E");
   E135 : Short_Integer; pragma Import (Ada, E135, "ada__tags_E");
   E125 : Short_Integer; pragma Import (Ada, E125, "ada__strings__text_buffers_E");
   E190 : Short_Integer; pragma Import (Ada, E190, "gnat_E");
   E189 : Short_Integer; pragma Import (Ada, E189, "interfaces__c__strings_E");
   E123 : Short_Integer; pragma Import (Ada, E123, "ada__streams_E");
   E175 : Short_Integer; pragma Import (Ada, E175, "system__file_control_block_E");
   E145 : Short_Integer; pragma Import (Ada, E145, "system__finalization_root_E");
   E121 : Short_Integer; pragma Import (Ada, E121, "ada__finalization_E");
   E172 : Short_Integer; pragma Import (Ada, E172, "system__file_io_E");
   E196 : Short_Integer; pragma Import (Ada, E196, "ada__streams__stream_io_E");
   E179 : Short_Integer; pragma Import (Ada, E179, "system__storage_pools_E");
   E209 : Short_Integer; pragma Import (Ada, E209, "system__storage_pools__subpools_E");
   E157 : Short_Integer; pragma Import (Ada, E157, "ada__strings__unbounded_E");
   E395 : Short_Integer; pragma Import (Ada, E395, "system__task_info_E");
   E107 : Short_Integer; pragma Import (Ada, E107, "ada__calendar_E");
   E515 : Short_Integer; pragma Import (Ada, E515, "ada__calendar__delays_E");
   E113 : Short_Integer; pragma Import (Ada, E113, "ada__calendar__time_zones_E");
   E181 : Short_Integer; pragma Import (Ada, E181, "ada__text_io_E");
   E389 : Short_Integer; pragma Import (Ada, E389, "system__task_primitives__operations_E");
   E205 : Short_Integer; pragma Import (Ada, E205, "system__pool_global_E");
   E508 : Short_Integer; pragma Import (Ada, E508, "gnat__sockets_E");
   E511 : Short_Integer; pragma Import (Ada, E511, "gnat__sockets__poll_E");
   E520 : Short_Integer; pragma Import (Ada, E520, "gnat__sockets__thin_common_E");
   E513 : Short_Integer; pragma Import (Ada, E513, "gnat__sockets__thin_E");
   E177 : Short_Integer; pragma Import (Ada, E177, "system__regexp_E");
   E105 : Short_Integer; pragma Import (Ada, E105, "ada__directories_E");
   E453 : Short_Integer; pragma Import (Ada, E453, "system__tasking__protected_objects_E");
   E309 : Short_Integer; pragma Import (Ada, E309, "cryptolib__errors_E");
   E305 : Short_Integer; pragma Import (Ada, E305, "cryptolib__ciphers_E");
   E317 : Short_Integer; pragma Import (Ada, E317, "cryptolib__os_random_E");
   E315 : Short_Integer; pragma Import (Ada, E315, "cryptolib__random_E");
   E451 : Short_Integer; pragma Import (Ada, E451, "http_client__cancellation_E");
   E435 : Short_Integer; pragma Import (Ada, E435, "http_client__headers_E");
   E437 : Short_Integer; pragma Import (Ada, E437, "http_client__http2_E");
   E477 : Short_Integer; pragma Import (Ada, E477, "http_client__http2__frames_E");
   E479 : Short_Integer; pragma Import (Ada, E479, "http_client__http2__hpack_E");
   E483 : Short_Integer; pragma Import (Ada, E483, "http_client__http2__settings_E");
   E489 : Short_Integer; pragma Import (Ada, E489, "http_client__quic_E");
   E487 : Short_Integer; pragma Import (Ada, E487, "http_client__http3_E");
   E441 : Short_Integer; pragma Import (Ada, E441, "http_client__request_bodies_E");
   E485 : Short_Integer; pragma Import (Ada, E485, "http_client__http2_execution_common_E");
   E469 : Short_Integer; pragma Import (Ada, E469, "http_client__resources_E");
   E467 : Short_Integer; pragma Import (Ada, E467, "http_client__diagnostics_E");
   E463 : Short_Integer; pragma Import (Ada, E463, "http_client__responses_E");
   E499 : Short_Integer; pragma Import (Ada, E499, "http_client__transports_E");
   E444 : Short_Integer; pragma Import (Ada, E444, "http_client__uri_E");
   E459 : Short_Integer; pragma Import (Ada, E459, "http_client__cookies_E");
   E495 : Short_Integer; pragma Import (Ada, E495, "http_client__proxies_E");
   E524 : Short_Integer; pragma Import (Ada, E524, "http_client__proxies__socks_E");
   E439 : Short_Integer; pragma Import (Ada, E439, "http_client__requests_E");
   E475 : Short_Integer; pragma Import (Ada, E475, "http_client__http1_E");
   E481 : Short_Integer; pragma Import (Ada, E481, "http_client__http2__mapping_E");
   E493 : Short_Integer; pragma Import (Ada, E493, "http_client__http3__mapping_E");
   E491 : Short_Integer; pragma Import (Ada, E491, "http_client__http3__execution_E");
   E504 : Short_Integer; pragma Import (Ada, E504, "http_client__tls__client_certificates_E");
   E506 : Short_Integer; pragma Import (Ada, E506, "http_client__transports__tcp_E");
   E522 : Short_Integer; pragma Import (Ada, E522, "http_client__transports__socks_E");
   E501 : Short_Integer; pragma Import (Ada, E501, "http_client__transports__tls_E");
   E201 : Short_Integer; pragma Import (Ada, E201, "project_tools__text_E");
   E194 : Short_Integer; pragma Import (Ada, E194, "project_tools__files_E");
   E215 : Short_Integer; pragma Import (Ada, E215, "project_tools__processes_E");
   E185 : Short_Integer; pragma Import (Ada, E185, "tool_support_E");
   E369 : Short_Integer; pragma Import (Ada, E369, "version__availability_E");
   E238 : Short_Integer; pragma Import (Ada, E238, "version__hash_E");
   E230 : Short_Integer; pragma Import (Ada, E230, "version__path_safety_E");
   E428 : Short_Integer; pragma Import (Ada, E428, "version__pkt_line_E");
   E236 : Short_Integer; pragma Import (Ada, E236, "version__platform_E");
   E222 : Short_Integer; pragma Import (Ada, E222, "version__files_E");
   E224 : Short_Integer; pragma Import (Ada, E224, "version__files__internal_E");
   E226 : Short_Integer; pragma Import (Ada, E226, "version__files__rollback_E");
   E228 : Short_Integer; pragma Import (Ada, E228, "version__filesystem_guard_E");
   E220 : Short_Integer; pragma Import (Ada, E220, "version__init_E");
   E406 : Short_Integer; pragma Import (Ada, E406, "version__ref_names_E");
   E374 : Short_Integer; pragma Import (Ada, E374, "version__transport_E");
   E376 : Short_Integer; pragma Import (Ada, E376, "version__transport__local_E");
   E526 : Short_Integer; pragma Import (Ada, E526, "version__transport__ssh_E");
   E371 : Short_Integer; pragma Import (Ada, E371, "version__repository_format_E");
   E367 : Short_Integer; pragma Import (Ada, E367, "version__repository_E");
   E402 : Short_Integer; pragma Import (Ada, E402, "version__config_E");
   E539 : Short_Integer; pragma Import (Ada, E539, "version__hooks_E");
   E244 : Short_Integer; pragma Import (Ada, E244, "zlib_E");
   E251 : Short_Integer; pragma Import (Ada, E251, "zlib__archive_listing_E");
   E265 : Short_Integer; pragma Import (Ada, E265, "zlib__bit_writer_E");
   E259 : Short_Integer; pragma Import (Ada, E259, "zlib__bits_E");
   E263 : Short_Integer; pragma Import (Ada, E263, "zlib__fixed_compress_E");
   E269 : Short_Integer; pragma Import (Ada, E269, "zlib__huffman_builder_E");
   E267 : Short_Integer; pragma Import (Ada, E267, "zlib__lz77_matcher_E");
   E253 : Short_Integer; pragma Import (Ada, E253, "zlib__block_chooser_E");
   E281 : Short_Integer; pragma Import (Ada, E281, "zlib__lzma2_encoder_E");
   E283 : Short_Integer; pragma Import (Ada, E283, "zlib__lzma_decoder_E");
   E297 : Short_Integer; pragma Import (Ada, E297, "zlib__lzma_encoder_selection_E");
   E291 : Short_Integer; pragma Import (Ada, E291, "zlib__lzma_match_finder_E");
   E277 : Short_Integer; pragma Import (Ada, E277, "zlib__lzma_properties_E");
   E275 : Short_Integer; pragma Import (Ada, E275, "zlib__lzma_core_E");
   E271 : Short_Integer; pragma Import (Ada, E271, "zlib__lzma2_decoder_E");
   E273 : Short_Integer; pragma Import (Ada, E273, "zlib__lzma2_framing_E");
   E285 : Short_Integer; pragma Import (Ada, E285, "zlib__lzma_encoder_E");
   E293 : Short_Integer; pragma Import (Ada, E293, "zlib__lzma_parser_E");
   E279 : Short_Integer; pragma Import (Ada, E279, "zlib__lzma_range_decoders_E");
   E289 : Short_Integer; pragma Import (Ada, E289, "zlib__lzma_range_encoder_E");
   E287 : Short_Integer; pragma Import (Ada, E287, "zlib__lzma_literals_E");
   E299 : Short_Integer; pragma Import (Ada, E299, "zlib__lzma_raw_E");
   E295 : Short_Integer; pragma Import (Ada, E295, "zlib__lzma_repetitions_E");
   E301 : Short_Integer; pragma Import (Ada, E301, "zlib__ppmd7_E");
   E303 : Short_Integer; pragma Import (Ada, E303, "zlib__seven_zip_aes_E");
   E341 : Short_Integer; pragma Import (Ada, E341, "zlib__seven_zip_encrypted_writing_E");
   E343 : Short_Integer; pragma Import (Ada, E343, "zlib__seven_zip_file_extraction_E");
   E347 : Short_Integer; pragma Import (Ada, E347, "zlib__seven_zip_filtered_writing_E");
   E327 : Short_Integer; pragma Import (Ada, E327, "zlib__seven_zip_filters_E");
   E329 : Short_Integer; pragma Import (Ada, E329, "zlib__seven_zip_graphs_E");
   E351 : Short_Integer; pragma Import (Ada, E351, "zlib__seven_zip_header_encryption_E");
   E325 : Short_Integer; pragma Import (Ada, E325, "zlib__seven_zip_methods_E");
   E323 : Short_Integer; pragma Import (Ada, E323, "zlib__seven_zip_coders_E");
   E345 : Short_Integer; pragma Import (Ada, E345, "zlib__seven_zip_file_writing_E");
   E349 : Short_Integer; pragma Import (Ada, E349, "zlib__seven_zip_folder_decoding_E");
   E331 : Short_Integer; pragma Import (Ada, E331, "zlib__seven_zip_numbers_E");
   E333 : Short_Integer; pragma Import (Ada, E333, "zlib__seven_zip_paths_E");
   E335 : Short_Integer; pragma Import (Ada, E335, "zlib__seven_zip_properties_E");
   E321 : Short_Integer; pragma Import (Ada, E321, "zlib__seven_zip_container_E");
   E353 : Short_Integer; pragma Import (Ada, E353, "zlib__seven_zip_header_reading_E");
   E357 : Short_Integer; pragma Import (Ada, E357, "zlib__seven_zip_volumes_E");
   E359 : Short_Integer; pragma Import (Ada, E359, "zlib__sliding_window_E");
   E261 : Short_Integer; pragma Import (Ada, E261, "zlib__stream_bits_E");
   E257 : Short_Integer; pragma Import (Ada, E257, "zlib__huffman_E");
   E255 : Short_Integer; pragma Import (Ada, E255, "zlib__deflate_tables_E");
   E361 : Short_Integer; pragma Import (Ada, E361, "zlib__stream_inflate_E");
   E465 : Short_Integer; pragma Import (Ada, E465, "http_client__zlib_decompression_E");
   E461 : Short_Integer; pragma Import (Ada, E461, "http_client__decompression_E");
   E449 : Short_Integer; pragma Import (Ada, E449, "http_client__response_streams_E");
   E497 : Short_Integer; pragma Import (Ada, E497, "http_client__response_streams__http2_io_E");
   E242 : Short_Integer; pragma Import (Ada, E242, "version__compression_E");
   E430 : Short_Integer; pragma Import (Ada, E430, "version__transport__http_E");
   E240 : Short_Integer; pragma Import (Ada, E240, "version__objects_E");
   E380 : Short_Integer; pragma Import (Ada, E380, "version__fetch_E");
   E418 : Short_Integer; pragma Import (Ada, E418, "version__history_E");
   E363 : Short_Integer; pragma Import (Ada, E363, "version__pack_E");
   E365 : Short_Integer; pragma Import (Ada, E365, "version__pack_index_E");
   E422 : Short_Integer; pragma Import (Ada, E422, "version__pack_index_cache_E");
   E420 : Short_Integer; pragma Import (Ada, E420, "version__object_cache_E");
   E410 : Short_Integer; pragma Import (Ada, E410, "version__packed_refs_E");
   E378 : Short_Integer; pragma Import (Ada, E378, "version__promisor_E");
   E416 : Short_Integer; pragma Import (Ada, E416, "version__ref_transaction_E");
   E404 : Short_Integer; pragma Import (Ada, E404, "version__fetch__internal_E");
   E542 : Short_Integer; pragma Import (Ada, E542, "version__reflog_E");
   E408 : Short_Integer; pragma Import (Ada, E408, "version__refs_E");
   E412 : Short_Integer; pragma Import (Ada, E412, "version__reftable_E");
   E414 : Short_Integer; pragma Import (Ada, E414, "version__reftable__writer_E");
   E426 : Short_Integer; pragma Import (Ada, E426, "version__shallow_E");
   E424 : Short_Integer; pragma Import (Ada, E424, "version__shallow_cache_E");
   E544 : Short_Integer; pragma Import (Ada, E544, "version__staging_E");
   E535 : Short_Integer; pragma Import (Ada, E535, "version__upload_pack_E");
   E537 : Short_Integer; pragma Import (Ada, E537, "version__write_E");

   Sec_Default_Sized_Stacks : array (1 .. 1) of aliased System.Secondary_Stack.SS_Stack (System.Parameters.Runtime_Default_Sec_Stack_Size);

   Local_Priority_Specific_Dispatching : constant String := "";
   Local_Interrupt_States : constant String := "";

   Is_Elaborated : Boolean := False;

   procedure finalize_library is
   begin
      declare
         procedure F1;
         pragma Import (Ada, F1, "version__fetch__finalize_body");
      begin
         E380 := E380 - 1;
         if E380 = 0 then
            F1;
         end if;
      end;
      declare
         procedure F2;
         pragma Import (Ada, F2, "version__write__finalize_body");
      begin
         E537 := E537 - 1;
         if E537 = 0 then
            F2;
         end if;
      end;
      E535 := E535 - 1;
      declare
         procedure F3;
         pragma Import (Ada, F3, "version__upload_pack__finalize_spec");
      begin
         if E535 = 0 then
            F3;
         end if;
      end;
      E544 := E544 - 1;
      declare
         procedure F4;
         pragma Import (Ada, F4, "version__staging__finalize_spec");
      begin
         if E544 = 0 then
            F4;
         end if;
      end;
      declare
         procedure F5;
         pragma Import (Ada, F5, "version__history__finalize_body");
      begin
         E418 := E418 - 1;
         if E418 = 0 then
            F5;
         end if;
      end;
      declare
         procedure F6;
         pragma Import (Ada, F6, "version__shallow__finalize_body");
      begin
         E426 := E426 - 1;
         if E426 = 0 then
            F6;
         end if;
      end;
      E408 := E408 - 1;
      E416 := E416 - 1;
      declare
         procedure F7;
         pragma Import (Ada, F7, "version__reftable__finalize_body");
      begin
         E412 := E412 - 1;
         if E412 = 0 then
            F7;
         end if;
      end;
      declare
         procedure F8;
         pragma Import (Ada, F8, "version__reftable__finalize_spec");
      begin
         if E412 = 0 then
            F8;
         end if;
      end;
      declare
         procedure F9;
         pragma Import (Ada, F9, "version__refs__finalize_spec");
      begin
         if E408 = 0 then
            F9;
         end if;
      end;
      E542 := E542 - 1;
      declare
         procedure F10;
         pragma Import (Ada, F10, "version__reflog__finalize_spec");
      begin
         if E542 = 0 then
            F10;
         end if;
      end;
      declare
         procedure F11;
         pragma Import (Ada, F11, "version__ref_transaction__finalize_spec");
      begin
         if E416 = 0 then
            F11;
         end if;
      end;
      E240 := E240 - 1;
      E420 := E420 - 1;
      E410 := E410 - 1;
      declare
         procedure F12;
         pragma Import (Ada, F12, "version__packed_refs__finalize_spec");
      begin
         if E410 = 0 then
            F12;
         end if;
      end;
      declare
         procedure F13;
         pragma Import (Ada, F13, "version__object_cache__finalize_spec");
      begin
         if E420 = 0 then
            F13;
         end if;
      end;
      declare
         procedure F14;
         pragma Import (Ada, F14, "version__pack_index_cache__finalize_body");
      begin
         E422 := E422 - 1;
         if E422 = 0 then
            F14;
         end if;
      end;
      declare
         procedure F15;
         pragma Import (Ada, F15, "version__pack_index_cache__finalize_spec");
      begin
         if E422 = 0 then
            F15;
         end if;
      end;
      declare
         procedure F16;
         pragma Import (Ada, F16, "version__pack__finalize_body");
      begin
         E363 := E363 - 1;
         if E363 = 0 then
            F16;
         end if;
      end;
      E365 := E365 - 1;
      declare
         procedure F17;
         pragma Import (Ada, F17, "version__pack_index__finalize_spec");
      begin
         if E365 = 0 then
            F17;
         end if;
      end;
      declare
         procedure F18;
         pragma Import (Ada, F18, "version__history__finalize_spec");
      begin
         if E418 = 0 then
            F18;
         end if;
      end;
      declare
         procedure F19;
         pragma Import (Ada, F19, "version__objects__finalize_spec");
      begin
         if E240 = 0 then
            F19;
         end if;
      end;
      E449 := E449 - 1;
      declare
         procedure F20;
         pragma Import (Ada, F20, "http_client__response_streams__finalize_spec");
      begin
         if E449 = 0 then
            F20;
         end if;
      end;
      declare
         procedure F21;
         pragma Import (Ada, F21, "zlib__finalize_body");
      begin
         E244 := E244 - 1;
         if E244 = 0 then
            F21;
         end if;
      end;
      declare
         procedure F22;
         pragma Import (Ada, F22, "zlib__seven_zip_volumes__finalize_body");
      begin
         E357 := E357 - 1;
         if E357 = 0 then
            F22;
         end if;
      end;
      declare
         procedure F23;
         pragma Import (Ada, F23, "zlib__seven_zip_file_writing__finalize_body");
      begin
         E345 := E345 - 1;
         if E345 = 0 then
            F23;
         end if;
      end;
      declare
         procedure F24;
         pragma Import (Ada, F24, "zlib__seven_zip_file_extraction__finalize_body");
      begin
         E343 := E343 - 1;
         if E343 = 0 then
            F24;
         end if;
      end;
      declare
         procedure F25;
         pragma Import (Ada, F25, "zlib__seven_zip_container__finalize_body");
      begin
         E321 := E321 - 1;
         if E321 = 0 then
            F25;
         end if;
      end;
      declare
         procedure F26;
         pragma Import (Ada, F26, "zlib__seven_zip_properties__finalize_body");
      begin
         E335 := E335 - 1;
         if E335 = 0 then
            F26;
         end if;
      end;
      declare
         procedure F27;
         pragma Import (Ada, F27, "zlib__seven_zip_filters__finalize_body");
      begin
         E327 := E327 - 1;
         if E327 = 0 then
            F27;
         end if;
      end;
      E259 := E259 - 1;
      declare
         procedure F28;
         pragma Import (Ada, F28, "zlib__bits__finalize_spec");
      begin
         if E259 = 0 then
            F28;
         end if;
      end;
      E265 := E265 - 1;
      declare
         procedure F29;
         pragma Import (Ada, F29, "zlib__bit_writer__finalize_spec");
      begin
         if E265 = 0 then
            F29;
         end if;
      end;
      E539 := E539 - 1;
      declare
         procedure F30;
         pragma Import (Ada, F30, "version__hooks__finalize_spec");
      begin
         if E539 = 0 then
            F30;
         end if;
      end;
      E402 := E402 - 1;
      declare
         procedure F31;
         pragma Import (Ada, F31, "version__config__finalize_spec");
      begin
         if E402 = 0 then
            F31;
         end if;
      end;
      declare
         procedure F32;
         pragma Import (Ada, F32, "version__transport__local__finalize_body");
      begin
         E376 := E376 - 1;
         if E376 = 0 then
            F32;
         end if;
      end;
      declare
         procedure F33;
         pragma Import (Ada, F33, "version__transport__local__finalize_spec");
      begin
         if E376 = 0 then
            F33;
         end if;
      end;
      E228 := E228 - 1;
      declare
         procedure F34;
         pragma Import (Ada, F34, "version__filesystem_guard__finalize_spec");
      begin
         if E228 = 0 then
            F34;
         end if;
      end;
      E428 := E428 - 1;
      declare
         procedure F35;
         pragma Import (Ada, F35, "version__pkt_line__finalize_spec");
      begin
         if E428 = 0 then
            F35;
         end if;
      end;
      E230 := E230 - 1;
      declare
         procedure F36;
         pragma Import (Ada, F36, "version__path_safety__finalize_spec");
      begin
         if E230 = 0 then
            F36;
         end if;
      end;
      declare
         procedure F37;
         pragma Import (Ada, F37, "project_tools__files__finalize_body");
      begin
         E194 := E194 - 1;
         if E194 = 0 then
            F37;
         end if;
      end;
      E501 := E501 - 1;
      declare
         procedure F38;
         pragma Import (Ada, F38, "http_client__transports__tls__finalize_spec");
      begin
         if E501 = 0 then
            F38;
         end if;
      end;
      E506 := E506 - 1;
      declare
         procedure F39;
         pragma Import (Ada, F39, "http_client__transports__tcp__finalize_spec");
      begin
         if E506 = 0 then
            F39;
         end if;
      end;
      E459 := E459 - 1;
      declare
         procedure F40;
         pragma Import (Ada, F40, "http_client__cookies__finalize_spec");
      begin
         if E459 = 0 then
            F40;
         end if;
      end;
      declare
         procedure F41;
         pragma Import (Ada, F41, "http_client__uri__finalize_body");
      begin
         E444 := E444 - 1;
         if E444 = 0 then
            F41;
         end if;
      end;
      E467 := E467 - 1;
      declare
         procedure F42;
         pragma Import (Ada, F42, "http_client__diagnostics__finalize_spec");
      begin
         if E467 = 0 then
            F42;
         end if;
      end;
      E441 := E441 - 1;
      declare
         procedure F43;
         pragma Import (Ada, F43, "http_client__request_bodies__finalize_spec");
      begin
         if E441 = 0 then
            F43;
         end if;
      end;
      E489 := E489 - 1;
      declare
         procedure F44;
         pragma Import (Ada, F44, "http_client__quic__finalize_spec");
      begin
         if E489 = 0 then
            F44;
         end if;
      end;
      E435 := E435 - 1;
      declare
         procedure F45;
         pragma Import (Ada, F45, "http_client__headers__finalize_spec");
      begin
         if E435 = 0 then
            F45;
         end if;
      end;
      declare
         procedure F46;
         pragma Import (Ada, F46, "ada__directories__finalize_body");
      begin
         E105 := E105 - 1;
         if E105 = 0 then
            F46;
         end if;
      end;
      declare
         procedure F47;
         pragma Import (Ada, F47, "ada__directories__finalize_spec");
      begin
         if E105 = 0 then
            F47;
         end if;
      end;
      E177 := E177 - 1;
      declare
         procedure F48;
         pragma Import (Ada, F48, "system__regexp__finalize_spec");
      begin
         if E177 = 0 then
            F48;
         end if;
      end;
      declare
         procedure F49;
         pragma Import (Ada, F49, "gnat__sockets__finalize_body");
      begin
         E508 := E508 - 1;
         if E508 = 0 then
            F49;
         end if;
      end;
      declare
         procedure F50;
         pragma Import (Ada, F50, "gnat__sockets__finalize_spec");
      begin
         if E508 = 0 then
            F50;
         end if;
      end;
      E205 := E205 - 1;
      declare
         procedure F51;
         pragma Import (Ada, F51, "system__pool_global__finalize_spec");
      begin
         if E205 = 0 then
            F51;
         end if;
      end;
      E181 := E181 - 1;
      declare
         procedure F52;
         pragma Import (Ada, F52, "ada__text_io__finalize_spec");
      begin
         if E181 = 0 then
            F52;
         end if;
      end;
      E157 := E157 - 1;
      declare
         procedure F53;
         pragma Import (Ada, F53, "ada__strings__unbounded__finalize_spec");
      begin
         if E157 = 0 then
            F53;
         end if;
      end;
      E209 := E209 - 1;
      declare
         procedure F54;
         pragma Import (Ada, F54, "system__storage_pools__subpools__finalize_spec");
      begin
         if E209 = 0 then
            F54;
         end if;
      end;
      E196 := E196 - 1;
      declare
         procedure F55;
         pragma Import (Ada, F55, "ada__streams__stream_io__finalize_spec");
      begin
         if E196 = 0 then
            F55;
         end if;
      end;
      declare
         procedure F56;
         pragma Import (Ada, F56, "system__file_io__finalize_body");
      begin
         E172 := E172 - 1;
         if E172 = 0 then
            F56;
         end if;
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

      if E011 = 0 then
         Ada.Exceptions'Elab_Spec;
      end if;
      if E015 = 0 then
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
      if E017 = 0 then
         System.Soft_Links.Initialize'Elab_Body;
      end if;
      E017 := E017 + 1;
      E015 := E015 + 1;
      if E039 = 0 then
         System.Traceback.Symbolic'Elab_Body;
      end if;
      E039 := E039 + 1;
      E011 := E011 + 1;
      if E234 = 0 then
         Ada.Assertions'Elab_Spec;
      end if;
      E234 := E234 + 1;
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
      if E190 = 0 then
         Gnat'Elab_Spec;
      end if;
      E190 := E190 + 1;
      if E189 = 0 then
         Interfaces.C.Strings'Elab_Spec;
      end if;
      E189 := E189 + 1;
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
      if E196 = 0 then
         Ada.Streams.Stream_Io'Elab_Spec;
      end if;
      E196 := E196 + 1;
      if E179 = 0 then
         System.Storage_Pools'Elab_Spec;
      end if;
      E179 := E179 + 1;
      if E209 = 0 then
         System.Storage_Pools.Subpools'Elab_Spec;
      end if;
      E209 := E209 + 1;
      if E157 = 0 then
         Ada.Strings.Unbounded'Elab_Spec;
      end if;
      E157 := E157 + 1;
      if E395 = 0 then
         System.Task_Info'Elab_Spec;
      end if;
      E395 := E395 + 1;
      if E107 = 0 then
         Ada.Calendar'Elab_Spec;
      end if;
      if E107 = 0 then
         Ada.Calendar'Elab_Body;
      end if;
      E107 := E107 + 1;
      if E515 = 0 then
         Ada.Calendar.Delays'Elab_Body;
      end if;
      E515 := E515 + 1;
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
      if E389 = 0 then
         System.Task_Primitives.Operations'Elab_Body;
      end if;
      E389 := E389 + 1;
      if E205 = 0 then
         System.Pool_Global'Elab_Spec;
      end if;
      E205 := E205 + 1;
      if E508 = 0 then
         Gnat.Sockets'Elab_Spec;
      end if;
      if E520 = 0 then
         Gnat.Sockets.Thin_Common'Elab_Spec;
      end if;
      E520 := E520 + 1;
      E513 := E513 + 1;
      if E508 = 0 then
         Gnat.Sockets'Elab_Body;
      end if;
      E508 := E508 + 1;
      E511 := E511 + 1;
      if E177 = 0 then
         System.Regexp'Elab_Spec;
      end if;
      E177 := E177 + 1;
      if E105 = 0 then
         Ada.Directories'Elab_Spec;
      end if;
      if E105 = 0 then
         Ada.Directories'Elab_Body;
      end if;
      E105 := E105 + 1;
      if E453 = 0 then
         System.Tasking.Protected_Objects'Elab_Body;
      end if;
      E453 := E453 + 1;
      E309 := E309 + 1;
      E305 := E305 + 1;
      E317 := E317 + 1;
      E315 := E315 + 1;
      E451 := E451 + 1;
      if E435 = 0 then
         Http_Client.Headers'Elab_Spec;
      end if;
      E435 := E435 + 1;
      E437 := E437 + 1;
      E477 := E477 + 1;
      E479 := E479 + 1;
      E483 := E483 + 1;
      if E489 = 0 then
         Http_Client.Quic'Elab_Spec;
      end if;
      if E489 = 0 then
         Http_Client.Quic'Elab_Body;
      end if;
      E489 := E489 + 1;
      E487 := E487 + 1;
      if E441 = 0 then
         Http_Client.Request_Bodies'Elab_Spec;
      end if;
      E441 := E441 + 1;
      E485 := E485 + 1;
      if E469 = 0 then
         Http_Client.Resources'Elab_Body;
      end if;
      E469 := E469 + 1;
      if E467 = 0 then
         Http_Client.Diagnostics'Elab_Spec;
      end if;
      if E467 = 0 then
         Http_Client.Diagnostics'Elab_Body;
      end if;
      E467 := E467 + 1;
      E463 := E463 + 1;
      E499 := E499 + 1;
      if E444 = 0 then
         Http_Client.Uri'Elab_Body;
      end if;
      E444 := E444 + 1;
      if E459 = 0 then
         Http_Client.Cookies'Elab_Spec;
      end if;
      E459 := E459 + 1;
      if E495 = 0 then
         Http_Client.Proxies'Elab_Spec;
      end if;
      E495 := E495 + 1;
      E524 := E524 + 1;
      E439 := E439 + 1;
      E475 := E475 + 1;
      E481 := E481 + 1;
      E493 := E493 + 1;
      E491 := E491 + 1;
      if E504 = 0 then
         Http_Client.Tls.Client_Certificates'Elab_Spec;
      end if;
      E504 := E504 + 1;
      if E506 = 0 then
         Http_Client.Transports.Tcp'Elab_Spec;
      end if;
      if E506 = 0 then
         Http_Client.Transports.Tcp'Elab_Body;
      end if;
      E506 := E506 + 1;
      E522 := E522 + 1;
      if E501 = 0 then
         Http_Client.Transports.Tls'Elab_Spec;
      end if;
      if E501 = 0 then
         Http_Client.Transports.Tls'Elab_Body;
      end if;
      E501 := E501 + 1;
      E201 := E201 + 1;
      if E194 = 0 then
         Project_Tools.Files'Elab_Body;
      end if;
      E194 := E194 + 1;
      E215 := E215 + 1;
      E185 := E185 + 1;
      E369 := E369 + 1;
      E238 := E238 + 1;
      if E230 = 0 then
         Version.Path_Safety'Elab_Spec;
      end if;
      E230 := E230 + 1;
      if E428 = 0 then
         Version.Pkt_Line'Elab_Spec;
      end if;
      E428 := E428 + 1;
      E236 := E236 + 1;
      E224 := E224 + 1;
      E226 := E226 + 1;
      if E228 = 0 then
         Version.Filesystem_Guard'Elab_Spec;
      end if;
      E228 := E228 + 1;
      E222 := E222 + 1;
      E220 := E220 + 1;
      E406 := E406 + 1;
      E374 := E374 + 1;
      if E376 = 0 then
         Version.Transport.Local'Elab_Spec;
      end if;
      if E376 = 0 then
         Version.Transport.Local'Elab_Body;
      end if;
      E376 := E376 + 1;
      E526 := E526 + 1;
      E371 := E371 + 1;
      E367 := E367 + 1;
      if E402 = 0 then
         Version.Config'Elab_Spec;
      end if;
      E402 := E402 + 1;
      if E539 = 0 then
         Version.Hooks'Elab_Spec;
      end if;
      E539 := E539 + 1;
      if E244 = 0 then
         Zlib'Elab_Spec;
      end if;
      E251 := E251 + 1;
      if E265 = 0 then
         Zlib.Bit_Writer'Elab_Spec;
      end if;
      E265 := E265 + 1;
      if E259 = 0 then
         Zlib.Bits'Elab_Spec;
      end if;
      E259 := E259 + 1;
      E269 := E269 + 1;
      E291 := E291 + 1;
      E277 := E277 + 1;
      if E275 = 0 then
         Zlib.Lzma_Core'Elab_Body;
      end if;
      E275 := E275 + 1;
      E273 := E273 + 1;
      E281 := E281 + 1;
      E297 := E297 + 1;
      E293 := E293 + 1;
      E279 := E279 + 1;
      E271 := E271 + 1;
      E283 := E283 + 1;
      E289 := E289 + 1;
      E287 := E287 + 1;
      E299 := E299 + 1;
      E295 := E295 + 1;
      E285 := E285 + 1;
      E301 := E301 + 1;
      E303 := E303 + 1;
      if E327 = 0 then
         Zlib.Seven_Zip_Filters'Elab_Body;
      end if;
      E327 := E327 + 1;
      E329 := E329 + 1;
      E325 := E325 + 1;
      E323 := E323 + 1;
      E331 := E331 + 1;
      E349 := E349 + 1;
      E333 := E333 + 1;
      if E335 = 0 then
         Zlib.Seven_Zip_Properties'Elab_Body;
      end if;
      E335 := E335 + 1;
      if E321 = 0 then
         Zlib.Seven_Zip_Container'Elab_Body;
      end if;
      E321 := E321 + 1;
      E341 := E341 + 1;
      if E343 = 0 then
         Zlib.Seven_Zip_File_Extraction'Elab_Body;
      end if;
      E343 := E343 + 1;
      if E345 = 0 then
         Zlib.Seven_Zip_File_Writing'Elab_Body;
      end if;
      E345 := E345 + 1;
      E347 := E347 + 1;
      E351 := E351 + 1;
      E353 := E353 + 1;
      if E357 = 0 then
         Zlib.Seven_Zip_Volumes'Elab_Body;
      end if;
      E357 := E357 + 1;
      E359 := E359 + 1;
      E261 := E261 + 1;
      E257 := E257 + 1;
      E255 := E255 + 1;
      E253 := E253 + 1;
      E263 := E263 + 1;
      E267 := E267 + 1;
      E361 := E361 + 1;
      if E244 = 0 then
         Zlib'Elab_Body;
      end if;
      E244 := E244 + 1;
      E465 := E465 + 1;
      E461 := E461 + 1;
      if E449 = 0 then
         Http_Client.Response_Streams'Elab_Spec;
      end if;
      E497 := E497 + 1;
      if E449 = 0 then
         Http_Client.Response_Streams'Elab_Body;
      end if;
      E449 := E449 + 1;
      E242 := E242 + 1;
      if E430 = 0 then
         Version.Transport.Http'Elab_Spec;
      end if;
      E430 := E430 + 1;
      if E240 = 0 then
         Version.Objects'Elab_Spec;
      end if;
      if E418 = 0 then
         Version.History'Elab_Spec;
      end if;
      if E365 = 0 then
         Version.Pack_Index'Elab_Spec;
      end if;
      E365 := E365 + 1;
      if E363 = 0 then
         Version.Pack'Elab_Body;
      end if;
      E363 := E363 + 1;
      if E422 = 0 then
         Version.Pack_Index_Cache'Elab_Spec;
      end if;
      if E422 = 0 then
         Version.Pack_Index_Cache'Elab_Body;
      end if;
      E422 := E422 + 1;
      if E420 = 0 then
         Version.Object_Cache'Elab_Spec;
      end if;
      if E410 = 0 then
         Version.Packed_Refs'Elab_Spec;
      end if;
      E410 := E410 + 1;
      E378 := E378 + 1;
      E420 := E420 + 1;
      E240 := E240 + 1;
      if E416 = 0 then
         Version.Ref_Transaction'Elab_Spec;
      end if;
      if E542 = 0 then
         Version.Reflog'Elab_Spec;
      end if;
      E542 := E542 + 1;
      if E408 = 0 then
         Version.Refs'Elab_Spec;
      end if;
      E404 := E404 + 1;
      if E412 = 0 then
         Version.Reftable'Elab_Spec;
      end if;
      if E412 = 0 then
         Version.Reftable'Elab_Body;
      end if;
      E412 := E412 + 1;
      E414 := E414 + 1;
      E416 := E416 + 1;
      E408 := E408 + 1;
      if E426 = 0 then
         Version.Shallow'Elab_Body;
      end if;
      E426 := E426 + 1;
      E424 := E424 + 1;
      if E418 = 0 then
         Version.History'Elab_Body;
      end if;
      E418 := E418 + 1;
      if E544 = 0 then
         Version.Staging'Elab_Spec;
      end if;
      E544 := E544 + 1;
      if E535 = 0 then
         Version.Upload_Pack'Elab_Spec;
      end if;
      E535 := E535 + 1;
      if E537 = 0 then
         Version.Write'Elab_Body;
      end if;
      E537 := E537 + 1;
      if E380 = 0 then
         Version.Fetch'Elab_Body;
      end if;
      E380 := E380 + 1;
   end adainit;

   procedure Ada_Main_Program;
   pragma Import (Ada, Ada_Main_Program, "_ada_check_ref_transaction_selftest");

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
   --   /home/bent/Projekte/Ada/version/tools/obj/tool_support.o
   --   /home/bent/Projekte/Ada/version/tools/obj/check_ref_transaction_selftest.o
   --   -L/home/bent/Projekte/Ada/version/tools/obj/
   --   -L/home/bent/Projekte/Ada/version/tools/obj/
   --   -L/home/bent/Projekte/Ada/version/obj/release/
   --   -L/home/bent/Projekte/Ada/project_tools/lib/
   --   -L/home/bent/Projekte/Ada/versionlib/lib/
   --   -L/home/bent/Projekte/Ada/ssh_lib_build/lib/
   --   -L/home/bent/Projekte/Ada/cryptolib/lib/
   --   -L/home/bent/Projekte/Ada/zlib/lib/
   --   -L/home/bent/Projekte/Ada/httpclient/lib/
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
