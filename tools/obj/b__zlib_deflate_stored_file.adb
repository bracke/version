pragma Warnings (Off);
pragma Ada_95;
pragma Source_File_Name (ada_main, Spec_File_Name => "b__zlib_deflate_stored_file.ads");
pragma Source_File_Name (ada_main, Body_File_Name => "b__zlib_deflate_stored_file.adb");
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
   E195 : Short_Integer; pragma Import (Ada, E195, "ada__assertions_E");
   E107 : Short_Integer; pragma Import (Ada, E107, "ada__strings__utf_encoding_E");
   E115 : Short_Integer; pragma Import (Ada, E115, "ada__tags_E");
   E105 : Short_Integer; pragma Import (Ada, E105, "ada__strings__text_buffers_E");
   E190 : Short_Integer; pragma Import (Ada, E190, "gnat_E");
   E123 : Short_Integer; pragma Import (Ada, E123, "ada__streams_E");
   E139 : Short_Integer; pragma Import (Ada, E139, "system__file_control_block_E");
   E134 : Short_Integer; pragma Import (Ada, E134, "system__finalization_root_E");
   E132 : Short_Integer; pragma Import (Ada, E132, "ada__finalization_E");
   E131 : Short_Integer; pragma Import (Ada, E131, "system__file_io_E");
   E187 : Short_Integer; pragma Import (Ada, E187, "ada__streams__stream_io_E");
   E185 : Short_Integer; pragma Import (Ada, E185, "system__storage_pools_E");
   E197 : Short_Integer; pragma Import (Ada, E197, "system__storage_pools__subpools_E");
   E172 : Short_Integer; pragma Import (Ada, E172, "ada__strings__unbounded_E");
   E145 : Short_Integer; pragma Import (Ada, E145, "ada__calendar_E");
   E157 : Short_Integer; pragma Import (Ada, E157, "ada__calendar__time_zones_E");
   E121 : Short_Integer; pragma Import (Ada, E121, "ada__text_io_E");
   E183 : Short_Integer; pragma Import (Ada, E183, "system__regexp_E");
   E153 : Short_Integer; pragma Import (Ada, E153, "ada__directories_E");
   E143 : Short_Integer; pragma Import (Ada, E143, "zlib_E");
   E201 : Short_Integer; pragma Import (Ada, E201, "zlib__bit_writer_E");
   E209 : Short_Integer; pragma Import (Ada, E209, "zlib__bits_E");
   E215 : Short_Integer; pragma Import (Ada, E215, "zlib__checksums_E");
   E221 : Short_Integer; pragma Import (Ada, E221, "zlib__crc32_internal_E");
   E213 : Short_Integer; pragma Import (Ada, E213, "zlib__fixed_compress_E");
   E219 : Short_Integer; pragma Import (Ada, E219, "zlib__huffman_builder_E");
   E217 : Short_Integer; pragma Import (Ada, E217, "zlib__lz77_matcher_E");
   E203 : Short_Integer; pragma Import (Ada, E203, "zlib__block_chooser_E");
   E223 : Short_Integer; pragma Import (Ada, E223, "zlib__sliding_window_E");
   E211 : Short_Integer; pragma Import (Ada, E211, "zlib__stream_bits_E");
   E207 : Short_Integer; pragma Import (Ada, E207, "zlib__huffman_E");
   E205 : Short_Integer; pragma Import (Ada, E205, "zlib__deflate_tables_E");
   E225 : Short_Integer; pragma Import (Ada, E225, "zlib__stream_inflate_E");

   Sec_Default_Sized_Stacks : array (1 .. 1) of aliased System.Secondary_Stack.SS_Stack (System.Parameters.Runtime_Default_Sec_Stack_Size);

   Local_Priority_Specific_Dispatching : constant String := "";
   Local_Interrupt_States : constant String := "";

   Is_Elaborated : Boolean := False;

   procedure finalize_library is
   begin
      declare
         procedure F1;
         pragma Import (Ada, F1, "zlib__finalize_body");
      begin
         E143 := E143 - 1;
         F1;
      end;
      E209 := E209 - 1;
      declare
         procedure F2;
         pragma Import (Ada, F2, "zlib__bits__finalize_spec");
      begin
         F2;
      end;
      E201 := E201 - 1;
      declare
         procedure F3;
         pragma Import (Ada, F3, "zlib__bit_writer__finalize_spec");
      begin
         F3;
      end;
      declare
         procedure F4;
         pragma Import (Ada, F4, "ada__directories__finalize_body");
      begin
         E153 := E153 - 1;
         F4;
      end;
      declare
         procedure F5;
         pragma Import (Ada, F5, "ada__directories__finalize_spec");
      begin
         F5;
      end;
      E183 := E183 - 1;
      declare
         procedure F6;
         pragma Import (Ada, F6, "system__regexp__finalize_spec");
      begin
         F6;
      end;
      E121 := E121 - 1;
      declare
         procedure F7;
         pragma Import (Ada, F7, "ada__text_io__finalize_spec");
      begin
         F7;
      end;
      E172 := E172 - 1;
      declare
         procedure F8;
         pragma Import (Ada, F8, "ada__strings__unbounded__finalize_spec");
      begin
         F8;
      end;
      E197 := E197 - 1;
      declare
         procedure F9;
         pragma Import (Ada, F9, "system__storage_pools__subpools__finalize_spec");
      begin
         F9;
      end;
      E187 := E187 - 1;
      declare
         procedure F10;
         pragma Import (Ada, F10, "ada__streams__stream_io__finalize_spec");
      begin
         F10;
      end;
      declare
         procedure F11;
         pragma Import (Ada, F11, "system__file_io__finalize_body");
      begin
         E131 := E131 - 1;
         F11;
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
      if E195 = 0 then
         Ada.Assertions'Elab_Spec;
      end if;
      E195 := E195 + 1;
      if E107 = 0 then
         Ada.Strings.Utf_Encoding'Elab_Spec;
      end if;
      E107 := E107 + 1;
      if E115 = 0 then
         Ada.Tags'Elab_Spec;
      end if;
      if E115 = 0 then
         Ada.Tags'Elab_Body;
      end if;
      E115 := E115 + 1;
      if E105 = 0 then
         Ada.Strings.Text_Buffers'Elab_Spec;
      end if;
      E105 := E105 + 1;
      if E190 = 0 then
         Gnat'Elab_Spec;
      end if;
      E190 := E190 + 1;
      if E123 = 0 then
         Ada.Streams'Elab_Spec;
      end if;
      E123 := E123 + 1;
      if E139 = 0 then
         System.File_Control_Block'Elab_Spec;
      end if;
      E139 := E139 + 1;
      if E134 = 0 then
         System.Finalization_Root'Elab_Spec;
      end if;
      E134 := E134 + 1;
      if E132 = 0 then
         Ada.Finalization'Elab_Spec;
      end if;
      E132 := E132 + 1;
      if E131 = 0 then
         System.File_Io'Elab_Body;
      end if;
      E131 := E131 + 1;
      if E187 = 0 then
         Ada.Streams.Stream_Io'Elab_Spec;
      end if;
      E187 := E187 + 1;
      if E185 = 0 then
         System.Storage_Pools'Elab_Spec;
      end if;
      E185 := E185 + 1;
      if E197 = 0 then
         System.Storage_Pools.Subpools'Elab_Spec;
      end if;
      E197 := E197 + 1;
      if E172 = 0 then
         Ada.Strings.Unbounded'Elab_Spec;
      end if;
      E172 := E172 + 1;
      if E145 = 0 then
         Ada.Calendar'Elab_Spec;
      end if;
      if E145 = 0 then
         Ada.Calendar'Elab_Body;
      end if;
      E145 := E145 + 1;
      if E157 = 0 then
         Ada.Calendar.Time_Zones'Elab_Spec;
      end if;
      E157 := E157 + 1;
      if E121 = 0 then
         Ada.Text_Io'Elab_Spec;
      end if;
      if E121 = 0 then
         Ada.Text_Io'Elab_Body;
      end if;
      E121 := E121 + 1;
      if E183 = 0 then
         System.Regexp'Elab_Spec;
      end if;
      E183 := E183 + 1;
      if E153 = 0 then
         Ada.Directories'Elab_Spec;
      end if;
      if E153 = 0 then
         Ada.Directories'Elab_Body;
      end if;
      E153 := E153 + 1;
      if E143 = 0 then
         Zlib'Elab_Spec;
      end if;
      if E201 = 0 then
         Zlib.Bit_Writer'Elab_Spec;
      end if;
      E201 := E201 + 1;
      if E209 = 0 then
         Zlib.Bits'Elab_Spec;
      end if;
      E209 := E209 + 1;
      E215 := E215 + 1;
      if E221 = 0 then
         Zlib.Crc32_Internal'Elab_Body;
      end if;
      E221 := E221 + 1;
      E219 := E219 + 1;
      E223 := E223 + 1;
      E211 := E211 + 1;
      E207 := E207 + 1;
      E205 := E205 + 1;
      E203 := E203 + 1;
      E213 := E213 + 1;
      E217 := E217 + 1;
      E225 := E225 + 1;
      if E143 = 0 then
         Zlib'Elab_Body;
      end if;
      E143 := E143 + 1;
   end adainit;

   procedure Ada_Main_Program;
   pragma Import (Ada, Ada_Main_Program, "_ada_zlib_deflate_stored_file");

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
   --   /home/bent/Projekte/Ada/version/tools/obj/zlib_deflate_stored_file.o
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
   --   -lgnat
   --   -ldl
--  END Object file/option list   

end ada_main;
