pragma Warnings (Off);
pragma Ada_95;
pragma Source_File_Name (ada_main, Spec_File_Name => "b__check_ref_transaction_selftest.ads");
pragma Source_File_Name (ada_main, Body_File_Name => "b__check_ref_transaction_selftest.adb");
pragma Suppress (Overflow_Check);

with System.Restrictions;
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
   E252 : Short_Integer; pragma Import (Ada, E252, "ada__assertions_E");
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
   E467 : Short_Integer; pragma Import (Ada, E467, "system__task_info_E");
   E222 : Short_Integer; pragma Import (Ada, E222, "system__regpat_E");
   E107 : Short_Integer; pragma Import (Ada, E107, "ada__calendar_E");
   E589 : Short_Integer; pragma Import (Ada, E589, "ada__calendar__delays_E");
   E113 : Short_Integer; pragma Import (Ada, E113, "ada__calendar__time_zones_E");
   E181 : Short_Integer; pragma Import (Ada, E181, "ada__text_io_E");
   E461 : Short_Integer; pragma Import (Ada, E461, "system__task_primitives__operations_E");
   E602 : Short_Integer; pragma Import (Ada, E602, "ada__real_time_E");
   E205 : Short_Integer; pragma Import (Ada, E205, "system__pool_global_E");
   E217 : Short_Integer; pragma Import (Ada, E217, "gnat__expect_E");
   E582 : Short_Integer; pragma Import (Ada, E582, "gnat__sockets_E");
   E585 : Short_Integer; pragma Import (Ada, E585, "gnat__sockets__poll_E");
   E594 : Short_Integer; pragma Import (Ada, E594, "gnat__sockets__thin_common_E");
   E587 : Short_Integer; pragma Import (Ada, E587, "gnat__sockets__thin_E");
   E177 : Short_Integer; pragma Import (Ada, E177, "system__regexp_E");
   E105 : Short_Integer; pragma Import (Ada, E105, "ada__directories_E");
   E729 : Short_Integer; pragma Import (Ada, E729, "system__tasking__initialization_E");
   E556 : Short_Integer; pragma Import (Ada, E556, "system__tasking__protected_objects_E");
   E733 : Short_Integer; pragma Import (Ada, E733, "system__tasking__protected_objects__entries_E");
   E737 : Short_Integer; pragma Import (Ada, E737, "system__tasking__queuing_E");
   E741 : Short_Integer; pragma Import (Ada, E741, "system__tasking__stages_E");
   E689 : Short_Integer; pragma Import (Ada, E689, "ssl__limits_E");
   E647 : Short_Integer; pragma Import (Ada, E647, "cryptolib__bignum_E");
   E669 : Short_Integer; pragma Import (Ada, E669, "cryptolib__chacha20_poly1305_E");
   E355 : Short_Integer; pragma Import (Ada, E355, "cryptolib__ciphers_E");
   E631 : Short_Integer; pragma Import (Ada, E631, "cryptolib__ec_arith_E");
   E641 : Short_Integer; pragma Import (Ada, E641, "cryptolib__field448_E");
   E675 : Short_Integer; pragma Import (Ada, E675, "cryptolib__hkdf_E");
   E635 : Short_Integer; pragma Import (Ada, E635, "cryptolib__modexp_E");
   E633 : Short_Integer; pragma Import (Ada, E633, "cryptolib__ec_curves_E");
   E367 : Short_Integer; pragma Import (Ada, E367, "cryptolib__os_random_E");
   E713 : Short_Integer; pragma Import (Ada, E713, "cryptolib__pbes2_E");
   E711 : Short_Integer; pragma Import (Ada, E711, "cryptolib__pkcs8_E");
   E365 : Short_Integer; pragma Import (Ada, E365, "cryptolib__random_E");
   E679 : Short_Integer; pragma Import (Ada, E679, "cryptolib__curve25519_E");
   E671 : Short_Integer; pragma Import (Ada, E671, "cryptolib__ecdh_E");
   E629 : Short_Integer; pragma Import (Ada, E629, "cryptolib__ecdsa_E");
   E637 : Short_Integer; pragma Import (Ada, E637, "cryptolib__ed25519_E");
   E639 : Short_Integer; pragma Import (Ada, E639, "cryptolib__ed448_E");
   E673 : Short_Integer; pragma Import (Ada, E673, "cryptolib__ffdhe_E");
   E645 : Short_Integer; pragma Import (Ada, E645, "cryptolib__rsa_E");
   E677 : Short_Integer; pragma Import (Ada, E677, "cryptolib__tls13_kdf_E");
   E623 : Short_Integer; pragma Import (Ada, E623, "cryptolib__x509__certificates_E");
   E761 : Short_Integer; pragma Import (Ada, E761, "cryptolib__identities_E");
   E621 : Short_Integer; pragma Import (Ada, E621, "cryptolib__x509__extensions_E");
   E649 : Short_Integer; pragma Import (Ada, E649, "cryptolib__x509__identity_E");
   E665 : Short_Integer; pragma Import (Ada, E665, "cryptolib__x509__names_E");
   E663 : Short_Integer; pragma Import (Ada, E663, "cryptolib__x509__name_constraints_E");
   E653 : Short_Integer; pragma Import (Ada, E653, "cryptolib__x509__policies_E");
   E655 : Short_Integer; pragma Import (Ada, E655, "cryptolib__x509__purposes_E");
   E627 : Short_Integer; pragma Import (Ada, E627, "cryptolib__x509__signatures_E");
   E613 : Short_Integer; pragma Import (Ada, E613, "cryptolib__ocsp_E");
   E709 : Short_Integer; pragma Import (Ada, E709, "cryptolib__pkcs10_E");
   E707 : Short_Integer; pragma Import (Ada, E707, "cryptolib__certificates_E");
   E659 : Short_Integer; pragma Import (Ada, E659, "cryptolib__x509__crls_E");
   E651 : Short_Integer; pragma Import (Ada, E651, "cryptolib__x509__path_building_E");
   E657 : Short_Integer; pragma Import (Ada, E657, "cryptolib__x509__revocation_E");
   E661 : Short_Integer; pragma Import (Ada, E661, "cryptolib__x509__validation_E");
   E232 : Short_Integer; pragma Import (Ada, E232, "hostkit_E");
   E256 : Short_Integer; pragma Import (Ada, E256, "hostkit__command_line_E");
   E258 : Short_Integer; pragma Import (Ada, E258, "hostkit__descriptors_E");
   E236 : Short_Integer; pragma Import (Ada, E236, "hostkit__filesystem_rules_E");
   E234 : Short_Integer; pragma Import (Ada, E234, "hostkit__fs_E");
   E715 : Short_Integer; pragma Import (Ada, E715, "hostkit__host_E");
   E721 : Short_Integer; pragma Import (Ada, E721, "hostkit__shell_E");
   E717 : Short_Integer; pragma Import (Ada, E717, "hostkit__process_E");
   E719 : Short_Integer; pragma Import (Ada, E719, "hostkit__native_E");
   E817 : Short_Integer; pragma Import (Ada, E817, "http_client__cancellation_E");
   E512 : Short_Integer; pragma Import (Ada, E512, "http_client__headers_E");
   E525 : Short_Integer; pragma Import (Ada, E525, "http_client__http2_E");
   E542 : Short_Integer; pragma Import (Ada, E542, "http_client__http2__frames_E");
   E570 : Short_Integer; pragma Import (Ada, E570, "http_client__http2__hpack_E");
   E538 : Short_Integer; pragma Import (Ada, E538, "http_client__http2__settings_E");
   E546 : Short_Integer; pragma Import (Ada, E546, "http_client__quic_E");
   E544 : Short_Integer; pragma Import (Ada, E544, "http_client__http3_E");
   E522 : Short_Integer; pragma Import (Ada, E522, "http_client__request_bodies_E");
   E540 : Short_Integer; pragma Import (Ada, E540, "http_client__http2_execution_common_E");
   E554 : Short_Integer; pragma Import (Ada, E554, "http_client__resources_E");
   E552 : Short_Integer; pragma Import (Ada, E552, "http_client__diagnostics_E");
   E566 : Short_Integer; pragma Import (Ada, E566, "http_client__responses_E");
   E572 : Short_Integer; pragma Import (Ada, E572, "http_client__transports_E");
   E518 : Short_Integer; pragma Import (Ada, E518, "http_client__uri_E");
   E532 : Short_Integer; pragma Import (Ada, E532, "http_client__cookies_E");
   E516 : Short_Integer; pragma Import (Ada, E516, "http_client__proxies_E");
   E578 : Short_Integer; pragma Import (Ada, E578, "http_client__proxies__socks_E");
   E520 : Short_Integer; pragma Import (Ada, E520, "http_client__requests_E");
   E510 : Short_Integer; pragma Import (Ada, E510, "http_client__auth_E");
   E534 : Short_Integer; pragma Import (Ada, E534, "http_client__http1_E");
   E536 : Short_Integer; pragma Import (Ada, E536, "http_client__http2__mapping_E");
   E550 : Short_Integer; pragma Import (Ada, E550, "http_client__http3__mapping_E");
   E548 : Short_Integer; pragma Import (Ada, E548, "http_client__http3__execution_E");
   E815 : Short_Integer; pragma Import (Ada, E815, "http_client__tls__client_certificates_E");
   E580 : Short_Integer; pragma Import (Ada, E580, "http_client__transports__tcp_E");
   E576 : Short_Integer; pragma Import (Ada, E576, "http_client__transports__socks_E");
   E201 : Short_Integer; pragma Import (Ada, E201, "project_tools__links_E");
   E203 : Short_Integer; pragma Import (Ada, E203, "project_tools__text_E");
   E194 : Short_Integer; pragma Import (Ada, E194, "project_tools__files_E");
   E215 : Short_Integer; pragma Import (Ada, E215, "project_tools__processes_E");
   E780 : Short_Integer; pragma Import (Ada, E780, "ssl__buffers_E");
   E782 : Short_Integer; pragma Import (Ada, E782, "ssl__cancellation_E");
   E697 : Short_Integer; pragma Import (Ada, E697, "ssl__clocks_E");
   E757 : Short_Integer; pragma Import (Ada, E757, "ssl__authentication_E");
   E784 : Short_Integer; pragma Import (Ada, E784, "ssl__connection_metadata_E");
   E685 : Short_Integer; pragma Import (Ada, E685, "ssl__errors_E");
   E763 : Short_Integer; pragma Import (Ada, E763, "ssl__diagnostics_E");
   E691 : Short_Integer; pragma Import (Ada, E691, "ssl__secrets_E");
   E667 : Short_Integer; pragma Import (Ada, E667, "ssl__crypto_E");
   E759 : Short_Integer; pragma Import (Ada, E759, "ssl__credentials_E");
   E778 : Short_Integer; pragma Import (Ada, E778, "ssl__key_schedule_E");
   E765 : Short_Integer; pragma Import (Ada, E765, "ssl__sessions_E");
   E767 : Short_Integer; pragma Import (Ada, E767, "ssl__sessions__client_caches_E");
   E788 : Short_Integer; pragma Import (Ada, E788, "ssl__tls12_E");
   E794 : Short_Integer; pragma Import (Ada, E794, "ssl__transcripts_E");
   E810 : Short_Integer; pragma Import (Ada, E810, "ssl__transports_E");
   E774 : Short_Integer; pragma Import (Ada, E774, "ssl__unsafe__key_logging_E");
   E753 : Short_Integer; pragma Import (Ada, E753, "ssl__wire_E");
   E776 : Short_Integer; pragma Import (Ada, E776, "ssl__extensions_E");
   E786 : Short_Integer; pragma Import (Ada, E786, "ssl__records_E");
   E769 : Short_Integer; pragma Import (Ada, E769, "ssl__ticket_keys_E");
   E796 : Short_Integer; pragma Import (Ada, E796, "ssl__tls12__records_E");
   E185 : Short_Integer; pragma Import (Ada, E185, "tool_support_E");
   E705 : Short_Integer; pragma Import (Ada, E705, "truststores_E");
   E701 : Short_Integer; pragma Import (Ada, E701, "ssl__trust_E");
   E771 : Short_Integer; pragma Import (Ada, E771, "ssl__trust__pinning_E");
   E749 : Short_Integer; pragma Import (Ada, E749, "ssl__trust__revocation_E");
   E608 : Short_Integer; pragma Import (Ada, E608, "ssl__certificate_validation_E");
   E755 : Short_Integer; pragma Import (Ada, E755, "ssl__configurations_E");
   E751 : Short_Integer; pragma Import (Ada, E751, "ssl__handshake_messages_E");
   E792 : Short_Integer; pragma Import (Ada, E792, "ssl__tls12__messages_E");
   E790 : Short_Integer; pragma Import (Ada, E790, "ssl__tls12__client_E");
   E798 : Short_Integer; pragma Import (Ada, E798, "ssl__tls12__server_E");
   E800 : Short_Integer; pragma Import (Ada, E800, "ssl__tls13_E");
   E802 : Short_Integer; pragma Import (Ada, E802, "ssl__tls13__client_E");
   E804 : Short_Integer; pragma Import (Ada, E804, "ssl__tls13__server_E");
   E606 : Short_Integer; pragma Import (Ada, E606, "ssl__engines_E");
   E808 : Short_Integer; pragma Import (Ada, E808, "ssl__engines__events_E");
   E806 : Short_Integer; pragma Import (Ada, E806, "ssl__connections_E");
   E600 : Short_Integer; pragma Import (Ada, E600, "ssl__blocking_E");
   E812 : Short_Integer; pragma Import (Ada, E812, "ssl__clients_E");
   E574 : Short_Integer; pragma Import (Ada, E574, "http_client__transports__tls_E");
   E442 : Short_Integer; pragma Import (Ada, E442, "version__availability_E");
   E263 : Short_Integer; pragma Import (Ada, E263, "version__hash_E");
   E248 : Short_Integer; pragma Import (Ada, E248, "version__path_safety_E");
   E501 : Short_Integer; pragma Import (Ada, E501, "version__pkt_line_E");
   E254 : Short_Integer; pragma Import (Ada, E254, "version__platform_E");
   E231 : Short_Integer; pragma Import (Ada, E231, "version__files_E");
   E242 : Short_Integer; pragma Import (Ada, E242, "version__files__internal_E");
   E244 : Short_Integer; pragma Import (Ada, E244, "version__files__rollback_E");
   E246 : Short_Integer; pragma Import (Ada, E246, "version__filesystem_guard_E");
   E479 : Short_Integer; pragma Import (Ada, E479, "version__ref_names_E");
   E483 : Short_Integer; pragma Import (Ada, E483, "version__timestamps_E");
   E447 : Short_Integer; pragma Import (Ada, E447, "version__transport_E");
   E449 : Short_Integer; pragma Import (Ada, E449, "version__transport__local_E");
   E824 : Short_Integer; pragma Import (Ada, E824, "version__transport__ssh_E");
   E444 : Short_Integer; pragma Import (Ada, E444, "version__repository_format_E");
   E440 : Short_Integer; pragma Import (Ada, E440, "version__repository_E");
   E839 : Short_Integer; pragma Import (Ada, E839, "version__hooks_E");
   E268 : Short_Integer; pragma Import (Ada, E268, "zlib_E");
   E272 : Short_Integer; pragma Import (Ada, E272, "zlib__ar_reader_E");
   E277 : Short_Integer; pragma Import (Ada, E277, "zlib__archive_listing_E");
   E291 : Short_Integer; pragma Import (Ada, E291, "zlib__bit_writer_E");
   E285 : Short_Integer; pragma Import (Ada, E285, "zlib__bits_E");
   E307 : Short_Integer; pragma Import (Ada, E307, "zlib__bzip2_bit_writer_E");
   E299 : Short_Integer; pragma Import (Ada, E299, "zlib__bzip2_bits_E");
   E309 : Short_Integer; pragma Import (Ada, E309, "zlib__bzip2_bwt_E");
   E301 : Short_Integer; pragma Import (Ada, E301, "zlib__bzip2_crc_E");
   E297 : Short_Integer; pragma Import (Ada, E297, "zlib__bzip2_decoder_E");
   E305 : Short_Integer; pragma Import (Ada, E305, "zlib__bzip2_encoder_E");
   E303 : Short_Integer; pragma Import (Ada, E303, "zlib__bzip2_huffman_E");
   E311 : Short_Integer; pragma Import (Ada, E311, "zlib__bzip2_lengths_E");
   E313 : Short_Integer; pragma Import (Ada, E313, "zlib__cab_reader_E");
   E315 : Short_Integer; pragma Import (Ada, E315, "zlib__cpio_reader_E");
   E289 : Short_Integer; pragma Import (Ada, E289, "zlib__fixed_compress_E");
   E295 : Short_Integer; pragma Import (Ada, E295, "zlib__huffman_builder_E");
   E317 : Short_Integer; pragma Import (Ada, E317, "zlib__iso_reader_E");
   E293 : Short_Integer; pragma Import (Ada, E293, "zlib__lz77_matcher_E");
   E279 : Short_Integer; pragma Import (Ada, E279, "zlib__block_chooser_E");
   E329 : Short_Integer; pragma Import (Ada, E329, "zlib__lzma2_encoder_E");
   E331 : Short_Integer; pragma Import (Ada, E331, "zlib__lzma_decoder_E");
   E345 : Short_Integer; pragma Import (Ada, E345, "zlib__lzma_encoder_selection_E");
   E339 : Short_Integer; pragma Import (Ada, E339, "zlib__lzma_match_finder_E");
   E325 : Short_Integer; pragma Import (Ada, E325, "zlib__lzma_properties_E");
   E323 : Short_Integer; pragma Import (Ada, E323, "zlib__lzma_core_E");
   E319 : Short_Integer; pragma Import (Ada, E319, "zlib__lzma2_decoder_E");
   E321 : Short_Integer; pragma Import (Ada, E321, "zlib__lzma2_framing_E");
   E333 : Short_Integer; pragma Import (Ada, E333, "zlib__lzma_encoder_E");
   E341 : Short_Integer; pragma Import (Ada, E341, "zlib__lzma_parser_E");
   E327 : Short_Integer; pragma Import (Ada, E327, "zlib__lzma_range_decoders_E");
   E337 : Short_Integer; pragma Import (Ada, E337, "zlib__lzma_range_encoder_E");
   E335 : Short_Integer; pragma Import (Ada, E335, "zlib__lzma_literals_E");
   E347 : Short_Integer; pragma Import (Ada, E347, "zlib__lzma_raw_E");
   E343 : Short_Integer; pragma Import (Ada, E343, "zlib__lzma_repetitions_E");
   E349 : Short_Integer; pragma Import (Ada, E349, "zlib__ppmd7_E");
   E351 : Short_Integer; pragma Import (Ada, E351, "zlib__rar_reader_E");
   E353 : Short_Integer; pragma Import (Ada, E353, "zlib__seven_zip_aes_E");
   E391 : Short_Integer; pragma Import (Ada, E391, "zlib__seven_zip_encrypted_writing_E");
   E393 : Short_Integer; pragma Import (Ada, E393, "zlib__seven_zip_file_extraction_E");
   E397 : Short_Integer; pragma Import (Ada, E397, "zlib__seven_zip_filtered_writing_E");
   E377 : Short_Integer; pragma Import (Ada, E377, "zlib__seven_zip_filters_E");
   E379 : Short_Integer; pragma Import (Ada, E379, "zlib__seven_zip_graphs_E");
   E401 : Short_Integer; pragma Import (Ada, E401, "zlib__seven_zip_header_encryption_E");
   E375 : Short_Integer; pragma Import (Ada, E375, "zlib__seven_zip_methods_E");
   E373 : Short_Integer; pragma Import (Ada, E373, "zlib__seven_zip_coders_E");
   E395 : Short_Integer; pragma Import (Ada, E395, "zlib__seven_zip_file_writing_E");
   E399 : Short_Integer; pragma Import (Ada, E399, "zlib__seven_zip_folder_decoding_E");
   E381 : Short_Integer; pragma Import (Ada, E381, "zlib__seven_zip_numbers_E");
   E383 : Short_Integer; pragma Import (Ada, E383, "zlib__seven_zip_paths_E");
   E385 : Short_Integer; pragma Import (Ada, E385, "zlib__seven_zip_properties_E");
   E371 : Short_Integer; pragma Import (Ada, E371, "zlib__seven_zip_container_E");
   E403 : Short_Integer; pragma Import (Ada, E403, "zlib__seven_zip_header_reading_E");
   E407 : Short_Integer; pragma Import (Ada, E407, "zlib__seven_zip_volumes_E");
   E409 : Short_Integer; pragma Import (Ada, E409, "zlib__sliding_window_E");
   E287 : Short_Integer; pragma Import (Ada, E287, "zlib__stream_bits_E");
   E283 : Short_Integer; pragma Import (Ada, E283, "zlib__huffman_E");
   E281 : Short_Integer; pragma Import (Ada, E281, "zlib__deflate_tables_E");
   E411 : Short_Integer; pragma Import (Ada, E411, "zlib__stream_inflate_E");
   E413 : Short_Integer; pragma Import (Ada, E413, "zlib__zip_aes_E");
   E419 : Short_Integer; pragma Import (Ada, E419, "zlib__zstd_bits_E");
   E417 : Short_Integer; pragma Import (Ada, E417, "zlib__zstd_decoder_E");
   E429 : Short_Integer; pragma Import (Ada, E429, "zlib__zstd_encoder_E");
   E423 : Short_Integer; pragma Import (Ada, E423, "zlib__zstd_tables_E");
   E421 : Short_Integer; pragma Import (Ada, E421, "zlib__zstd_fse_E");
   E425 : Short_Integer; pragma Import (Ada, E425, "zlib__zstd_huffman_E");
   E427 : Short_Integer; pragma Import (Ada, E427, "zlib__zstd_xxh64_E");
   E822 : Short_Integer; pragma Import (Ada, E822, "http_client__zlib_decompression_E");
   E819 : Short_Integer; pragma Import (Ada, E819, "http_client__decompression_E");
   E530 : Short_Integer; pragma Import (Ada, E530, "http_client__response_streams_E");
   E568 : Short_Integer; pragma Import (Ada, E568, "http_client__response_streams__http2_io_E");
   E433 : Short_Integer; pragma Import (Ada, E433, "version__compression_E");
   E473 : Short_Integer; pragma Import (Ada, E473, "version__config_E");
   E528 : Short_Integer; pragma Import (Ada, E528, "version__credential_E");
   E431 : Short_Integer; pragma Import (Ada, E431, "version__objects_E");
   E489 : Short_Integer; pragma Import (Ada, E489, "version__history_E");
   E435 : Short_Integer; pragma Import (Ada, E435, "version__pack_E");
   E438 : Short_Integer; pragma Import (Ada, E438, "version__pack_index_E");
   E493 : Short_Integer; pragma Import (Ada, E493, "version__pack_index_cache_E");
   E491 : Short_Integer; pragma Import (Ada, E491, "version__object_cache_E");
   E477 : Short_Integer; pragma Import (Ada, E477, "version__packed_refs_E");
   E451 : Short_Integer; pragma Import (Ada, E451, "version__promisor_E");
   E487 : Short_Integer; pragma Import (Ada, E487, "version__ref_transaction_E");
   E842 : Short_Integer; pragma Import (Ada, E842, "version__reflog_E");
   E475 : Short_Integer; pragma Import (Ada, E475, "version__refs_E");
   E260 : Short_Integer; pragma Import (Ada, E260, "version__reftable_E");
   E481 : Short_Integer; pragma Import (Ada, E481, "version__reftable__writer_E");
   E503 : Short_Integer; pragma Import (Ada, E503, "version__remotes_E");
   E505 : Short_Integer; pragma Import (Ada, E505, "version__remotes__test_hooks_E");
   E497 : Short_Integer; pragma Import (Ada, E497, "version__shallow_E");
   E495 : Short_Integer; pragma Import (Ada, E495, "version__shallow_cache_E");
   E844 : Short_Integer; pragma Import (Ada, E844, "version__staging_E");
   E507 : Short_Integer; pragma Import (Ada, E507, "version__transport__http_E");
   E499 : Short_Integer; pragma Import (Ada, E499, "version__tree_cache_E");
   E833 : Short_Integer; pragma Import (Ada, E833, "version__upload_pack_E");
   E453 : Short_Integer; pragma Import (Ada, E453, "version__fetch_E");
   E485 : Short_Integer; pragma Import (Ada, E485, "version__fetch__internal_E");
   E835 : Short_Integer; pragma Import (Ada, E835, "version__url_rewrite_E");
   E837 : Short_Integer; pragma Import (Ada, E837, "version__write_E");
   E229 : Short_Integer; pragma Import (Ada, E229, "version__init_E");

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
         E453 := E453 - 1;
         if E453 = 0 then
            F1;
         end if;
      end;
      declare
         procedure F2;
         pragma Import (Ada, F2, "version__write__finalize_body");
      begin
         E837 := E837 - 1;
         if E837 = 0 then
            F2;
         end if;
      end;
      declare
         procedure F3;
         pragma Import (Ada, F3, "version__remotes__finalize_body");
      begin
         E503 := E503 - 1;
         if E503 = 0 then
            F3;
         end if;
      end;
      E833 := E833 - 1;
      declare
         procedure F4;
         pragma Import (Ada, F4, "version__upload_pack__finalize_spec");
      begin
         if E833 = 0 then
            F4;
         end if;
      end;
      declare
         procedure F5;
         pragma Import (Ada, F5, "version__history__finalize_body");
      begin
         E489 := E489 - 1;
         if E489 = 0 then
            F5;
         end if;
      end;
      E499 := E499 - 1;
      declare
         procedure F6;
         pragma Import (Ada, F6, "version__tree_cache__finalize_spec");
      begin
         if E499 = 0 then
            F6;
         end if;
      end;
      E844 := E844 - 1;
      declare
         procedure F7;
         pragma Import (Ada, F7, "version__staging__finalize_spec");
      begin
         if E844 = 0 then
            F7;
         end if;
      end;
      declare
         procedure F8;
         pragma Import (Ada, F8, "version__shallow__finalize_body");
      begin
         E497 := E497 - 1;
         if E497 = 0 then
            F8;
         end if;
      end;
      declare
         procedure F9;
         pragma Import (Ada, F9, "version__remotes__finalize_spec");
      begin
         if E503 = 0 then
            F9;
         end if;
      end;
      E475 := E475 - 1;
      E842 := E842 - 1;
      E487 := E487 - 1;
      declare
         procedure F10;
         pragma Import (Ada, F10, "version__reftable__writer__finalize_body");
      begin
         E481 := E481 - 1;
         if E481 = 0 then
            F10;
         end if;
      end;
      declare
         procedure F11;
         pragma Import (Ada, F11, "version__reftable__finalize_body");
      begin
         E260 := E260 - 1;
         if E260 = 0 then
            F11;
         end if;
      end;
      declare
         procedure F12;
         pragma Import (Ada, F12, "version__reftable__finalize_spec");
      begin
         if E260 = 0 then
            F12;
         end if;
      end;
      E473 := E473 - 1;
      declare
         procedure F13;
         pragma Import (Ada, F13, "version__refs__finalize_spec");
      begin
         if E475 = 0 then
            F13;
         end if;
      end;
      declare
         procedure F14;
         pragma Import (Ada, F14, "version__reflog__finalize_spec");
      begin
         if E842 = 0 then
            F14;
         end if;
      end;
      declare
         procedure F15;
         pragma Import (Ada, F15, "version__ref_transaction__finalize_spec");
      begin
         if E487 = 0 then
            F15;
         end if;
      end;
      E431 := E431 - 1;
      E491 := E491 - 1;
      E477 := E477 - 1;
      declare
         procedure F16;
         pragma Import (Ada, F16, "version__packed_refs__finalize_spec");
      begin
         if E477 = 0 then
            F16;
         end if;
      end;
      declare
         procedure F17;
         pragma Import (Ada, F17, "version__object_cache__finalize_spec");
      begin
         if E491 = 0 then
            F17;
         end if;
      end;
      declare
         procedure F18;
         pragma Import (Ada, F18, "version__pack_index_cache__finalize_body");
      begin
         E493 := E493 - 1;
         if E493 = 0 then
            F18;
         end if;
      end;
      declare
         procedure F19;
         pragma Import (Ada, F19, "version__pack_index_cache__finalize_spec");
      begin
         if E493 = 0 then
            F19;
         end if;
      end;
      declare
         procedure F20;
         pragma Import (Ada, F20, "version__pack__finalize_body");
      begin
         E435 := E435 - 1;
         if E435 = 0 then
            F20;
         end if;
      end;
      E438 := E438 - 1;
      declare
         procedure F21;
         pragma Import (Ada, F21, "version__pack_index__finalize_spec");
      begin
         if E438 = 0 then
            F21;
         end if;
      end;
      declare
         procedure F22;
         pragma Import (Ada, F22, "version__history__finalize_spec");
      begin
         if E489 = 0 then
            F22;
         end if;
      end;
      declare
         procedure F23;
         pragma Import (Ada, F23, "version__objects__finalize_spec");
      begin
         if E431 = 0 then
            F23;
         end if;
      end;
      declare
         procedure F24;
         pragma Import (Ada, F24, "version__config__finalize_spec");
      begin
         if E473 = 0 then
            F24;
         end if;
      end;
      E530 := E530 - 1;
      declare
         procedure F25;
         pragma Import (Ada, F25, "http_client__response_streams__finalize_spec");
      begin
         if E530 = 0 then
            F25;
         end if;
      end;
      declare
         procedure F26;
         pragma Import (Ada, F26, "zlib__zstd_encoder__finalize_body");
      begin
         E429 := E429 - 1;
         if E429 = 0 then
            F26;
         end if;
      end;
      declare
         procedure F27;
         pragma Import (Ada, F27, "zlib__zstd_decoder__finalize_body");
      begin
         E417 := E417 - 1;
         if E417 = 0 then
            F27;
         end if;
      end;
      declare
         procedure F28;
         pragma Import (Ada, F28, "zlib__finalize_body");
      begin
         E268 := E268 - 1;
         if E268 = 0 then
            F28;
         end if;
      end;
      E419 := E419 - 1;
      declare
         procedure F29;
         pragma Import (Ada, F29, "zlib__zstd_bits__finalize_spec");
      begin
         if E419 = 0 then
            F29;
         end if;
      end;
      declare
         procedure F30;
         pragma Import (Ada, F30, "zlib__seven_zip_volumes__finalize_body");
      begin
         E407 := E407 - 1;
         if E407 = 0 then
            F30;
         end if;
      end;
      declare
         procedure F31;
         pragma Import (Ada, F31, "zlib__seven_zip_file_writing__finalize_body");
      begin
         E395 := E395 - 1;
         if E395 = 0 then
            F31;
         end if;
      end;
      declare
         procedure F32;
         pragma Import (Ada, F32, "zlib__seven_zip_file_extraction__finalize_body");
      begin
         E393 := E393 - 1;
         if E393 = 0 then
            F32;
         end if;
      end;
      declare
         procedure F33;
         pragma Import (Ada, F33, "zlib__seven_zip_container__finalize_body");
      begin
         E371 := E371 - 1;
         if E371 = 0 then
            F33;
         end if;
      end;
      declare
         procedure F34;
         pragma Import (Ada, F34, "zlib__seven_zip_properties__finalize_body");
      begin
         E385 := E385 - 1;
         if E385 = 0 then
            F34;
         end if;
      end;
      declare
         procedure F35;
         pragma Import (Ada, F35, "zlib__seven_zip_filters__finalize_body");
      begin
         E377 := E377 - 1;
         if E377 = 0 then
            F35;
         end if;
      end;
      declare
         procedure F36;
         pragma Import (Ada, F36, "zlib__rar_reader__finalize_body");
      begin
         E351 := E351 - 1;
         if E351 = 0 then
            F36;
         end if;
      end;
      declare
         procedure F37;
         pragma Import (Ada, F37, "zlib__iso_reader__finalize_body");
      begin
         E317 := E317 - 1;
         if E317 = 0 then
            F37;
         end if;
      end;
      declare
         procedure F38;
         pragma Import (Ada, F38, "zlib__cpio_reader__finalize_body");
      begin
         E315 := E315 - 1;
         if E315 = 0 then
            F38;
         end if;
      end;
      declare
         procedure F39;
         pragma Import (Ada, F39, "zlib__bzip2_decoder__finalize_body");
      begin
         E297 := E297 - 1;
         if E297 = 0 then
            F39;
         end if;
      end;
      E307 := E307 - 1;
      declare
         procedure F40;
         pragma Import (Ada, F40, "zlib__bzip2_bit_writer__finalize_spec");
      begin
         if E307 = 0 then
            F40;
         end if;
      end;
      E285 := E285 - 1;
      declare
         procedure F41;
         pragma Import (Ada, F41, "zlib__bits__finalize_spec");
      begin
         if E285 = 0 then
            F41;
         end if;
      end;
      E291 := E291 - 1;
      declare
         procedure F42;
         pragma Import (Ada, F42, "zlib__bit_writer__finalize_spec");
      begin
         if E291 = 0 then
            F42;
         end if;
      end;
      declare
         procedure F43;
         pragma Import (Ada, F43, "zlib__ar_reader__finalize_body");
      begin
         E272 := E272 - 1;
         if E272 = 0 then
            F43;
         end if;
      end;
      E839 := E839 - 1;
      declare
         procedure F44;
         pragma Import (Ada, F44, "version__hooks__finalize_spec");
      begin
         if E839 = 0 then
            F44;
         end if;
      end;
      declare
         procedure F45;
         pragma Import (Ada, F45, "version__transport__local__finalize_body");
      begin
         E449 := E449 - 1;
         if E449 = 0 then
            F45;
         end if;
      end;
      declare
         procedure F46;
         pragma Import (Ada, F46, "version__transport__local__finalize_spec");
      begin
         if E449 = 0 then
            F46;
         end if;
      end;
      E246 := E246 - 1;
      declare
         procedure F47;
         pragma Import (Ada, F47, "version__filesystem_guard__finalize_spec");
      begin
         if E246 = 0 then
            F47;
         end if;
      end;
      E501 := E501 - 1;
      declare
         procedure F48;
         pragma Import (Ada, F48, "version__pkt_line__finalize_spec");
      begin
         if E501 = 0 then
            F48;
         end if;
      end;
      E248 := E248 - 1;
      declare
         procedure F49;
         pragma Import (Ada, F49, "version__path_safety__finalize_spec");
      begin
         if E248 = 0 then
            F49;
         end if;
      end;
      declare
         procedure F50;
         pragma Import (Ada, F50, "http_client__transports__tls__finalize_body");
      begin
         E574 := E574 - 1;
         if E574 = 0 then
            F50;
         end if;
      end;
      declare
         procedure F51;
         pragma Import (Ada, F51, "http_client__transports__tls__finalize_spec");
      begin
         if E574 = 0 then
            F51;
         end if;
      end;
      E755 := E755 - 1;
      declare
         procedure F52;
         pragma Import (Ada, F52, "ssl__configurations__finalize_spec");
      begin
         if E755 = 0 then
            F52;
         end if;
      end;
      declare
         procedure F53;
         pragma Import (Ada, F53, "ssl__certificate_validation__finalize_body");
      begin
         E608 := E608 - 1;
         if E608 = 0 then
            F53;
         end if;
      end;
      E701 := E701 - 1;
      declare
         procedure F54;
         pragma Import (Ada, F54, "ssl__trust__finalize_spec");
      begin
         if E701 = 0 then
            F54;
         end if;
      end;
      E769 := E769 - 1;
      declare
         procedure F55;
         pragma Import (Ada, F55, "ssl__ticket_keys__finalize_spec");
      begin
         if E769 = 0 then
            F55;
         end if;
      end;
      E774 := E774 - 1;
      declare
         procedure F56;
         pragma Import (Ada, F56, "ssl__unsafe__key_logging__finalize_spec");
      begin
         if E774 = 0 then
            F56;
         end if;
      end;
      E810 := E810 - 1;
      declare
         procedure F57;
         pragma Import (Ada, F57, "ssl__transports__finalize_spec");
      begin
         if E810 = 0 then
            F57;
         end if;
      end;
      E767 := E767 - 1;
      declare
         procedure F58;
         pragma Import (Ada, F58, "ssl__sessions__client_caches__finalize_spec");
      begin
         if E767 = 0 then
            F58;
         end if;
      end;
      E759 := E759 - 1;
      declare
         procedure F59;
         pragma Import (Ada, F59, "ssl__credentials__finalize_spec");
      begin
         if E759 = 0 then
            F59;
         end if;
      end;
      E691 := E691 - 1;
      declare
         procedure F60;
         pragma Import (Ada, F60, "ssl__secrets__finalize_spec");
      begin
         if E691 = 0 then
            F60;
         end if;
      end;
      E763 := E763 - 1;
      declare
         procedure F61;
         pragma Import (Ada, F61, "ssl__diagnostics__finalize_spec");
      begin
         if E763 = 0 then
            F61;
         end if;
      end;
      E780 := E780 - 1;
      declare
         procedure F62;
         pragma Import (Ada, F62, "ssl__buffers__finalize_spec");
      begin
         if E780 = 0 then
            F62;
         end if;
      end;
      E215 := E215 - 1;
      declare
         procedure F63;
         pragma Import (Ada, F63, "project_tools__processes__finalize_spec");
      begin
         if E215 = 0 then
            F63;
         end if;
      end;
      declare
         procedure F64;
         pragma Import (Ada, F64, "project_tools__files__finalize_body");
      begin
         E194 := E194 - 1;
         if E194 = 0 then
            F64;
         end if;
      end;
      E580 := E580 - 1;
      declare
         procedure F65;
         pragma Import (Ada, F65, "http_client__transports__tcp__finalize_spec");
      begin
         if E580 = 0 then
            F65;
         end if;
      end;
      E532 := E532 - 1;
      declare
         procedure F66;
         pragma Import (Ada, F66, "http_client__cookies__finalize_spec");
      begin
         if E532 = 0 then
            F66;
         end if;
      end;
      declare
         procedure F67;
         pragma Import (Ada, F67, "http_client__uri__finalize_body");
      begin
         E518 := E518 - 1;
         if E518 = 0 then
            F67;
         end if;
      end;
      E552 := E552 - 1;
      declare
         procedure F68;
         pragma Import (Ada, F68, "http_client__diagnostics__finalize_spec");
      begin
         if E552 = 0 then
            F68;
         end if;
      end;
      E522 := E522 - 1;
      declare
         procedure F69;
         pragma Import (Ada, F69, "http_client__request_bodies__finalize_spec");
      begin
         if E522 = 0 then
            F69;
         end if;
      end;
      E546 := E546 - 1;
      declare
         procedure F70;
         pragma Import (Ada, F70, "http_client__quic__finalize_spec");
      begin
         if E546 = 0 then
            F70;
         end if;
      end;
      E512 := E512 - 1;
      declare
         procedure F71;
         pragma Import (Ada, F71, "http_client__headers__finalize_spec");
      begin
         if E512 = 0 then
            F71;
         end if;
      end;
      declare
         procedure F72;
         pragma Import (Ada, F72, "hostkit__finalize_spec");
      begin
         E232 := E232 - 1;
         if E232 = 0 then
            F72;
         end if;
      end;
      E761 := E761 - 1;
      declare
         procedure F73;
         pragma Import (Ada, F73, "cryptolib__identities__finalize_spec");
      begin
         if E761 = 0 then
            F73;
         end if;
      end;
      E711 := E711 - 1;
      declare
         procedure F74;
         pragma Import (Ada, F74, "cryptolib__pkcs8__finalize_spec");
      begin
         if E711 = 0 then
            F74;
         end if;
      end;
      E733 := E733 - 1;
      declare
         procedure F75;
         pragma Import (Ada, F75, "system__tasking__protected_objects__entries__finalize_spec");
      begin
         if E733 = 0 then
            F75;
         end if;
      end;
      declare
         procedure F76;
         pragma Import (Ada, F76, "ada__directories__finalize_body");
      begin
         E105 := E105 - 1;
         if E105 = 0 then
            F76;
         end if;
      end;
      declare
         procedure F77;
         pragma Import (Ada, F77, "ada__directories__finalize_spec");
      begin
         if E105 = 0 then
            F77;
         end if;
      end;
      E177 := E177 - 1;
      declare
         procedure F78;
         pragma Import (Ada, F78, "system__regexp__finalize_spec");
      begin
         if E177 = 0 then
            F78;
         end if;
      end;
      declare
         procedure F79;
         pragma Import (Ada, F79, "gnat__sockets__finalize_body");
      begin
         E582 := E582 - 1;
         if E582 = 0 then
            F79;
         end if;
      end;
      declare
         procedure F80;
         pragma Import (Ada, F80, "gnat__sockets__finalize_spec");
      begin
         if E582 = 0 then
            F80;
         end if;
      end;
      E217 := E217 - 1;
      declare
         procedure F81;
         pragma Import (Ada, F81, "gnat__expect__finalize_spec");
      begin
         if E217 = 0 then
            F81;
         end if;
      end;
      E205 := E205 - 1;
      declare
         procedure F82;
         pragma Import (Ada, F82, "system__pool_global__finalize_spec");
      begin
         if E205 = 0 then
            F82;
         end if;
      end;
      E181 := E181 - 1;
      declare
         procedure F83;
         pragma Import (Ada, F83, "ada__text_io__finalize_spec");
      begin
         if E181 = 0 then
            F83;
         end if;
      end;
      E157 := E157 - 1;
      declare
         procedure F84;
         pragma Import (Ada, F84, "ada__strings__unbounded__finalize_spec");
      begin
         if E157 = 0 then
            F84;
         end if;
      end;
      E209 := E209 - 1;
      declare
         procedure F85;
         pragma Import (Ada, F85, "system__storage_pools__subpools__finalize_spec");
      begin
         if E209 = 0 then
            F85;
         end if;
      end;
      E196 := E196 - 1;
      declare
         procedure F86;
         pragma Import (Ada, F86, "ada__streams__stream_io__finalize_spec");
      begin
         if E196 = 0 then
            F86;
         end if;
      end;
      declare
         procedure F87;
         pragma Import (Ada, F87, "system__file_io__finalize_body");
      begin
         E172 := E172 - 1;
         if E172 = 0 then
            F87;
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
      System.Restrictions.Run_Time_Restrictions :=
        (Set =>
          (False, False, False, False, False, False, False, False, 
           False, False, False, False, False, False, False, False, 
           False, False, False, False, False, False, False, False, 
           False, False, False, False, False, False, False, False, 
           False, False, False, False, False, False, False, False, 
           False, False, False, False, False, False, False, False, 
           False, False, False, False, False, False, False, False, 
           False, False, False, False, False, False, False, False, 
           False, False, False, False, False, False, False, False, 
           False, False, False, False, False, False, False, False, 
           False, False, False, True, False, False, False, False, 
           False, False, False, False, False, False, False, False, 
           False, False, False, False),
         Value => (0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
         Violated =>
          (False, False, False, False, True, True, False, False, 
           True, False, False, True, True, True, True, False, 
           False, False, False, True, False, False, True, True, 
           False, True, True, False, True, True, True, True, 
           False, False, False, False, False, True, True, False, 
           False, True, False, True, False, True, True, False, 
           True, False, True, True, False, False, True, False, 
           True, False, True, False, False, False, False, False, 
           False, True, True, True, True, True, False, False, 
           True, False, True, True, True, False, True, True, 
           False, True, True, True, True, False, False, False, 
           True, False, False, False, False, False, True, True, 
           True, False, True, False),
         Count => (0, 0, 0, 0, 2, 2, 2, 0, 3, 0),
         Unknown => (False, False, False, False, False, False, True, False, True, False));
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
      if E252 = 0 then
         Ada.Assertions'Elab_Spec;
      end if;
      E252 := E252 + 1;
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
      if E467 = 0 then
         System.Task_Info'Elab_Spec;
      end if;
      E467 := E467 + 1;
      if E222 = 0 then
         System.Regpat'Elab_Spec;
      end if;
      E222 := E222 + 1;
      if E107 = 0 then
         Ada.Calendar'Elab_Spec;
      end if;
      if E107 = 0 then
         Ada.Calendar'Elab_Body;
      end if;
      E107 := E107 + 1;
      if E589 = 0 then
         Ada.Calendar.Delays'Elab_Body;
      end if;
      E589 := E589 + 1;
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
      if E461 = 0 then
         System.Task_Primitives.Operations'Elab_Body;
      end if;
      E461 := E461 + 1;
      if E602 = 0 then
         Ada.Real_Time'Elab_Spec;
      end if;
      if E602 = 0 then
         Ada.Real_Time'Elab_Body;
      end if;
      E602 := E602 + 1;
      if E205 = 0 then
         System.Pool_Global'Elab_Spec;
      end if;
      E205 := E205 + 1;
      if E217 = 0 then
         Gnat.Expect'Elab_Spec;
      end if;
      E217 := E217 + 1;
      if E582 = 0 then
         Gnat.Sockets'Elab_Spec;
      end if;
      if E594 = 0 then
         Gnat.Sockets.Thin_Common'Elab_Spec;
      end if;
      E594 := E594 + 1;
      E587 := E587 + 1;
      if E582 = 0 then
         Gnat.Sockets'Elab_Body;
      end if;
      E582 := E582 + 1;
      E585 := E585 + 1;
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
      if E729 = 0 then
         System.Tasking.Initialization'Elab_Body;
      end if;
      E729 := E729 + 1;
      if E556 = 0 then
         System.Tasking.Protected_Objects'Elab_Body;
      end if;
      E556 := E556 + 1;
      if E733 = 0 then
         System.Tasking.Protected_Objects.Entries'Elab_Spec;
      end if;
      E733 := E733 + 1;
      if E737 = 0 then
         System.Tasking.Queuing'Elab_Body;
      end if;
      E737 := E737 + 1;
      if E741 = 0 then
         System.Tasking.Stages'Elab_Body;
      end if;
      E741 := E741 + 1;
      if E689 = 0 then
         SSL.LIMITS'ELAB_SPEC;
      end if;
      E689 := E689 + 1;
      E647 := E647 + 1;
      E669 := E669 + 1;
      E355 := E355 + 1;
      E631 := E631 + 1;
      E641 := E641 + 1;
      E675 := E675 + 1;
      E635 := E635 + 1;
      E633 := E633 + 1;
      E367 := E367 + 1;
      E713 := E713 + 1;
      if E711 = 0 then
         Cryptolib.Pkcs8'Elab_Spec;
      end if;
      if E711 = 0 then
         Cryptolib.Pkcs8'Elab_Body;
      end if;
      E711 := E711 + 1;
      E365 := E365 + 1;
      E679 := E679 + 1;
      E671 := E671 + 1;
      E629 := E629 + 1;
      E637 := E637 + 1;
      E639 := E639 + 1;
      E673 := E673 + 1;
      E645 := E645 + 1;
      E677 := E677 + 1;
      E623 := E623 + 1;
      if E761 = 0 then
         Cryptolib.Identities'Elab_Spec;
      end if;
      if E761 = 0 then
         CRYPTOLIB.IDENTITIES'ELAB_BODY;
      end if;
      E761 := E761 + 1;
      E621 := E621 + 1;
      E649 := E649 + 1;
      E665 := E665 + 1;
      E663 := E663 + 1;
      E653 := E653 + 1;
      E655 := E655 + 1;
      E627 := E627 + 1;
      E613 := E613 + 1;
      E709 := E709 + 1;
      E707 := E707 + 1;
      E659 := E659 + 1;
      if E651 = 0 then
         Cryptolib.X509.Path_Building'Elab_Spec;
      end if;
      E651 := E651 + 1;
      E657 := E657 + 1;
      if E661 = 0 then
         Cryptolib.X509.Validation'Elab_Spec;
      end if;
      E661 := E661 + 1;
      if E232 = 0 then
         Hostkit'Elab_Spec;
      end if;
      E232 := E232 + 1;
      E256 := E256 + 1;
      E258 := E258 + 1;
      E236 := E236 + 1;
      E234 := E234 + 1;
      E715 := E715 + 1;
      E721 := E721 + 1;
      E719 := E719 + 1;
      if E717 = 0 then
         Hostkit.Process'Elab_Body;
      end if;
      E717 := E717 + 1;
      E817 := E817 + 1;
      if E512 = 0 then
         Http_Client.Headers'Elab_Spec;
      end if;
      E512 := E512 + 1;
      E525 := E525 + 1;
      E542 := E542 + 1;
      E570 := E570 + 1;
      E538 := E538 + 1;
      if E546 = 0 then
         Http_Client.Quic'Elab_Spec;
      end if;
      if E546 = 0 then
         Http_Client.Quic'Elab_Body;
      end if;
      E546 := E546 + 1;
      E544 := E544 + 1;
      if E522 = 0 then
         Http_Client.Request_Bodies'Elab_Spec;
      end if;
      E522 := E522 + 1;
      E540 := E540 + 1;
      if E554 = 0 then
         Http_Client.Resources'Elab_Body;
      end if;
      E554 := E554 + 1;
      if E552 = 0 then
         Http_Client.Diagnostics'Elab_Spec;
      end if;
      if E552 = 0 then
         Http_Client.Diagnostics'Elab_Body;
      end if;
      E552 := E552 + 1;
      E566 := E566 + 1;
      E572 := E572 + 1;
      if E518 = 0 then
         Http_Client.Uri'Elab_Body;
      end if;
      E518 := E518 + 1;
      if E532 = 0 then
         Http_Client.Cookies'Elab_Spec;
      end if;
      E532 := E532 + 1;
      if E516 = 0 then
         Http_Client.Proxies'Elab_Spec;
      end if;
      E516 := E516 + 1;
      E578 := E578 + 1;
      E520 := E520 + 1;
      E510 := E510 + 1;
      E534 := E534 + 1;
      E536 := E536 + 1;
      E550 := E550 + 1;
      E548 := E548 + 1;
      if E815 = 0 then
         Http_Client.Tls.Client_Certificates'Elab_Spec;
      end if;
      E815 := E815 + 1;
      if E580 = 0 then
         Http_Client.Transports.Tcp'Elab_Spec;
      end if;
      if E580 = 0 then
         Http_Client.Transports.Tcp'Elab_Body;
      end if;
      E580 := E580 + 1;
      E576 := E576 + 1;
      E201 := E201 + 1;
      E203 := E203 + 1;
      if E194 = 0 then
         Project_Tools.Files'Elab_Body;
      end if;
      E194 := E194 + 1;
      if E215 = 0 then
         Project_Tools.Processes'Elab_Spec;
      end if;
      E215 := E215 + 1;
      if E780 = 0 then
         SSL.BUFFERS'ELAB_SPEC;
      end if;
      if E780 = 0 then
         SSL.BUFFERS'ELAB_BODY;
      end if;
      E780 := E780 + 1;
      E782 := E782 + 1;
      E697 := E697 + 1;
      E757 := E757 + 1;
      E784 := E784 + 1;
      E685 := E685 + 1;
      if E763 = 0 then
         SSL.DIAGNOSTICS'ELAB_SPEC;
      end if;
      E763 := E763 + 1;
      if E691 = 0 then
         SSL.SECRETS'ELAB_SPEC;
      end if;
      if E691 = 0 then
         SSL.SECRETS'ELAB_BODY;
      end if;
      E691 := E691 + 1;
      E667 := E667 + 1;
      if E759 = 0 then
         SSL.CREDENTIALS'ELAB_SPEC;
      end if;
      if E759 = 0 then
         SSL.CREDENTIALS'ELAB_BODY;
      end if;
      E759 := E759 + 1;
      E778 := E778 + 1;
      E765 := E765 + 1;
      if E767 = 0 then
         SSL.SESSIONS.CLIENT_CACHES'ELAB_SPEC;
      end if;
      E767 := E767 + 1;
      E788 := E788 + 1;
      E794 := E794 + 1;
      if E810 = 0 then
         SSL.TRANSPORTS'ELAB_SPEC;
      end if;
      E810 := E810 + 1;
      if E774 = 0 then
         SSL.UNSAFE.KEY_LOGGING'ELAB_SPEC;
      end if;
      E774 := E774 + 1;
      E753 := E753 + 1;
      E776 := E776 + 1;
      E786 := E786 + 1;
      if E769 = 0 then
         SSL.TICKET_KEYS'ELAB_SPEC;
      end if;
      E769 := E769 + 1;
      E796 := E796 + 1;
      E185 := E185 + 1;
      if E705 = 0 then
         Truststores'Elab_Body;
      end if;
      E705 := E705 + 1;
      if E701 = 0 then
         SSL.TRUST'ELAB_SPEC;
      end if;
      if E701 = 0 then
         SSL.TRUST'ELAB_BODY;
      end if;
      E701 := E701 + 1;
      E771 := E771 + 1;
      E749 := E749 + 1;
      if E608 = 0 then
         SSL.CERTIFICATE_VALIDATION'ELAB_BODY;
      end if;
      E608 := E608 + 1;
      if E755 = 0 then
         SSL.CONFIGURATIONS'ELAB_SPEC;
      end if;
      E755 := E755 + 1;
      E751 := E751 + 1;
      E792 := E792 + 1;
      E790 := E790 + 1;
      E798 := E798 + 1;
      E800 := E800 + 1;
      E802 := E802 + 1;
      E804 := E804 + 1;
      E606 := E606 + 1;
      E808 := E808 + 1;
      E806 := E806 + 1;
      E600 := E600 + 1;
      E812 := E812 + 1;
      if E574 = 0 then
         Http_Client.Transports.Tls'Elab_Spec;
      end if;
      if E574 = 0 then
         Http_Client.Transports.Tls'Elab_Body;
      end if;
      E574 := E574 + 1;
      E442 := E442 + 1;
      E263 := E263 + 1;
      if E248 = 0 then
         Version.Path_Safety'Elab_Spec;
      end if;
      E248 := E248 + 1;
      if E501 = 0 then
         Version.Pkt_Line'Elab_Spec;
      end if;
      E501 := E501 + 1;
      E254 := E254 + 1;
      E242 := E242 + 1;
      E244 := E244 + 1;
      if E246 = 0 then
         Version.Filesystem_Guard'Elab_Spec;
      end if;
      E246 := E246 + 1;
      E231 := E231 + 1;
      E479 := E479 + 1;
      E483 := E483 + 1;
      E447 := E447 + 1;
      if E449 = 0 then
         Version.Transport.Local'Elab_Spec;
      end if;
      if E449 = 0 then
         Version.Transport.Local'Elab_Body;
      end if;
      E449 := E449 + 1;
      E824 := E824 + 1;
      E444 := E444 + 1;
      E440 := E440 + 1;
      if E839 = 0 then
         Version.Hooks'Elab_Spec;
      end if;
      E839 := E839 + 1;
      if E268 = 0 then
         Zlib'Elab_Spec;
      end if;
      if E272 = 0 then
         Zlib.Ar_Reader'Elab_Body;
      end if;
      E272 := E272 + 1;
      E277 := E277 + 1;
      if E291 = 0 then
         Zlib.Bit_Writer'Elab_Spec;
      end if;
      E291 := E291 + 1;
      if E285 = 0 then
         Zlib.Bits'Elab_Spec;
      end if;
      E285 := E285 + 1;
      if E307 = 0 then
         Zlib.Bzip2_Bit_Writer'Elab_Spec;
      end if;
      E307 := E307 + 1;
      E299 := E299 + 1;
      E309 := E309 + 1;
      if E301 = 0 then
         Zlib.Bzip2_Crc'Elab_Body;
      end if;
      E301 := E301 + 1;
      E303 := E303 + 1;
      if E297 = 0 then
         Zlib.Bzip2_Decoder'Elab_Body;
      end if;
      E297 := E297 + 1;
      E311 := E311 + 1;
      E305 := E305 + 1;
      if E313 = 0 then
         Zlib.Cab_Reader'Elab_Body;
      end if;
      E313 := E313 + 1;
      if E315 = 0 then
         Zlib.Cpio_Reader'Elab_Body;
      end if;
      E315 := E315 + 1;
      E295 := E295 + 1;
      if E317 = 0 then
         Zlib.Iso_Reader'Elab_Body;
      end if;
      E317 := E317 + 1;
      E339 := E339 + 1;
      E325 := E325 + 1;
      if E323 = 0 then
         Zlib.Lzma_Core'Elab_Body;
      end if;
      E323 := E323 + 1;
      E321 := E321 + 1;
      E329 := E329 + 1;
      E345 := E345 + 1;
      E341 := E341 + 1;
      E327 := E327 + 1;
      E319 := E319 + 1;
      E331 := E331 + 1;
      E337 := E337 + 1;
      E335 := E335 + 1;
      E347 := E347 + 1;
      E343 := E343 + 1;
      E333 := E333 + 1;
      E349 := E349 + 1;
      if E351 = 0 then
         Zlib.Rar_Reader'Elab_Body;
      end if;
      E351 := E351 + 1;
      E353 := E353 + 1;
      if E377 = 0 then
         Zlib.Seven_Zip_Filters'Elab_Body;
      end if;
      E377 := E377 + 1;
      E379 := E379 + 1;
      E375 := E375 + 1;
      E373 := E373 + 1;
      E381 := E381 + 1;
      E399 := E399 + 1;
      E383 := E383 + 1;
      if E385 = 0 then
         Zlib.Seven_Zip_Properties'Elab_Body;
      end if;
      E385 := E385 + 1;
      if E371 = 0 then
         Zlib.Seven_Zip_Container'Elab_Body;
      end if;
      E371 := E371 + 1;
      E391 := E391 + 1;
      if E393 = 0 then
         Zlib.Seven_Zip_File_Extraction'Elab_Body;
      end if;
      E393 := E393 + 1;
      if E395 = 0 then
         Zlib.Seven_Zip_File_Writing'Elab_Body;
      end if;
      E395 := E395 + 1;
      E397 := E397 + 1;
      E401 := E401 + 1;
      E403 := E403 + 1;
      if E407 = 0 then
         Zlib.Seven_Zip_Volumes'Elab_Body;
      end if;
      E407 := E407 + 1;
      E409 := E409 + 1;
      E287 := E287 + 1;
      E283 := E283 + 1;
      E281 := E281 + 1;
      E279 := E279 + 1;
      E289 := E289 + 1;
      E293 := E293 + 1;
      E411 := E411 + 1;
      E413 := E413 + 1;
      if E419 = 0 then
         Zlib.Zstd_Bits'Elab_Spec;
      end if;
      E419 := E419 + 1;
      if E268 = 0 then
         Zlib'Elab_Body;
      end if;
      E268 := E268 + 1;
      E423 := E423 + 1;
      E421 := E421 + 1;
      E425 := E425 + 1;
      E427 := E427 + 1;
      if E417 = 0 then
         Zlib.Zstd_Decoder'Elab_Body;
      end if;
      E417 := E417 + 1;
      if E429 = 0 then
         Zlib.Zstd_Encoder'Elab_Body;
      end if;
      E429 := E429 + 1;
      E822 := E822 + 1;
      E819 := E819 + 1;
      if E530 = 0 then
         Http_Client.Response_Streams'Elab_Spec;
      end if;
      E568 := E568 + 1;
      if E530 = 0 then
         Http_Client.Response_Streams'Elab_Body;
      end if;
      E530 := E530 + 1;
      E433 := E433 + 1;
      if E473 = 0 then
         Version.Config'Elab_Spec;
      end if;
      E528 := E528 + 1;
      if E431 = 0 then
         Version.Objects'Elab_Spec;
      end if;
      if E489 = 0 then
         Version.History'Elab_Spec;
      end if;
      if E438 = 0 then
         Version.Pack_Index'Elab_Spec;
      end if;
      E438 := E438 + 1;
      if E435 = 0 then
         Version.Pack'Elab_Body;
      end if;
      E435 := E435 + 1;
      if E493 = 0 then
         Version.Pack_Index_Cache'Elab_Spec;
      end if;
      if E493 = 0 then
         Version.Pack_Index_Cache'Elab_Body;
      end if;
      E493 := E493 + 1;
      if E491 = 0 then
         Version.Object_Cache'Elab_Spec;
      end if;
      if E477 = 0 then
         Version.Packed_Refs'Elab_Spec;
      end if;
      E477 := E477 + 1;
      E491 := E491 + 1;
      E431 := E431 + 1;
      if E487 = 0 then
         Version.Ref_Transaction'Elab_Spec;
      end if;
      if E842 = 0 then
         Version.Reflog'Elab_Spec;
      end if;
      if E475 = 0 then
         Version.Refs'Elab_Spec;
      end if;
      E473 := E473 + 1;
      if E260 = 0 then
         Version.Reftable'Elab_Spec;
      end if;
      if E260 = 0 then
         Version.Reftable'Elab_Body;
      end if;
      E260 := E260 + 1;
      if E481 = 0 then
         Version.Reftable.Writer'Elab_Body;
      end if;
      E481 := E481 + 1;
      E487 := E487 + 1;
      E842 := E842 + 1;
      E475 := E475 + 1;
      if E503 = 0 then
         Version.Remotes'Elab_Spec;
      end if;
      E505 := E505 + 1;
      if E497 = 0 then
         Version.Shallow'Elab_Body;
      end if;
      E497 := E497 + 1;
      E495 := E495 + 1;
      if E844 = 0 then
         Version.Staging'Elab_Spec;
      end if;
      E844 := E844 + 1;
      if E507 = 0 then
         Version.Transport.Http'Elab_Spec;
      end if;
      E507 := E507 + 1;
      if E499 = 0 then
         Version.Tree_Cache'Elab_Spec;
      end if;
      E499 := E499 + 1;
      if E489 = 0 then
         Version.History'Elab_Body;
      end if;
      E489 := E489 + 1;
      if E833 = 0 then
         Version.Upload_Pack'Elab_Spec;
      end if;
      E833 := E833 + 1;
      E485 := E485 + 1;
      E451 := E451 + 1;
      if E503 = 0 then
         Version.Remotes'Elab_Body;
      end if;
      E503 := E503 + 1;
      E835 := E835 + 1;
      if E837 = 0 then
         Version.Write'Elab_Body;
      end if;
      E837 := E837 + 1;
      if E453 = 0 then
         Version.Fetch'Elab_Body;
      end if;
      E453 := E453 + 1;
      E229 := E229 + 1;
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
   --   -L/home/bent/Projekte/Ada/hostkit/lib/
   --   -L/home/bent/Projekte/Ada/zlib/lib/
   --   -L/home/bent/Projekte/Ada/httpclient/lib/
   --   -L/home/bent/Projekte/Ada/ssllib/lib/
   --   -L/home/bent/Projekte/Ada/truststores/lib/
   --   -L/home/bent/Projekte/Ada/i18n/lib/
   --   -L/home/bent/Projekte/Ada/regexp/lib/
   --   -L/home/bent/.local/share/alire/toolchains/gnat_native_15.2.1_4640d4b3/lib/gcc/x86_64-pc-linux-gnu/15.2.0/adalib/
   --   -static
   --   -lgnarl
   --   -lgnat
   --   -lrt
   --   -lpthread
   --   -ldl
--  END Object file/option list   

end ada_main;
