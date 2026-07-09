pragma Warnings (Off);
pragma Ada_95;
pragma Source_File_Name (ada_main, Spec_File_Name => "b__check_release_consistency.ads");
pragma Source_File_Name (ada_main, Body_File_Name => "b__check_release_consistency.adb");
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
   E107 : Short_Integer; pragma Import (Ada, E107, "ada__strings__utf_encoding_E");
   E115 : Short_Integer; pragma Import (Ada, E115, "ada__tags_E");
   E105 : Short_Integer; pragma Import (Ada, E105, "ada__strings__text_buffers_E");
   E191 : Short_Integer; pragma Import (Ada, E191, "gnat_E");
   E240 : Short_Integer; pragma Import (Ada, E240, "interfaces__c__strings_E");
   E123 : Short_Integer; pragma Import (Ada, E123, "ada__streams_E");
   E139 : Short_Integer; pragma Import (Ada, E139, "system__file_control_block_E");
   E134 : Short_Integer; pragma Import (Ada, E134, "system__finalization_root_E");
   E132 : Short_Integer; pragma Import (Ada, E132, "ada__finalization_E");
   E131 : Short_Integer; pragma Import (Ada, E131, "system__file_io_E");
   E188 : Short_Integer; pragma Import (Ada, E188, "ada__streams__stream_io_E");
   E186 : Short_Integer; pragma Import (Ada, E186, "system__storage_pools_E");
   E204 : Short_Integer; pragma Import (Ada, E204, "system__storage_pools__subpools_E");
   E144 : Short_Integer; pragma Import (Ada, E144, "ada__strings__unbounded_E");
   E229 : Short_Integer; pragma Import (Ada, E229, "system__task_info_E");
   E164 : Short_Integer; pragma Import (Ada, E164, "ada__calendar_E");
   E170 : Short_Integer; pragma Import (Ada, E170, "ada__calendar__time_zones_E");
   E121 : Short_Integer; pragma Import (Ada, E121, "ada__text_io_E");
   E223 : Short_Integer; pragma Import (Ada, E223, "system__task_primitives__operations_E");
   E200 : Short_Integer; pragma Import (Ada, E200, "system__pool_global_E");
   E184 : Short_Integer; pragma Import (Ada, E184, "system__regexp_E");
   E162 : Short_Integer; pragma Import (Ada, E162, "ada__directories_E");
   E194 : Short_Integer; pragma Import (Ada, E194, "project_tools__text_E");
   E158 : Short_Integer; pragma Import (Ada, E158, "project_tools__files_E");
   E210 : Short_Integer; pragma Import (Ada, E210, "project_tools__processes_E");
   E142 : Short_Integer; pragma Import (Ada, E142, "project_tools__release_checks_E");
   E236 : Short_Integer; pragma Import (Ada, E236, "tool_support_E");
   E215 : Short_Integer; pragma Import (Ada, E215, "tool_doc_guards_E");

   Sec_Default_Sized_Stacks : array (1 .. 1) of aliased System.Secondary_Stack.SS_Stack (System.Parameters.Runtime_Default_Sec_Stack_Size);

   Local_Priority_Specific_Dispatching : constant String := "";
   Local_Interrupt_States : constant String := "";

   Is_Elaborated : Boolean := False;

   procedure finalize_library is
   begin
      declare
         procedure F1;
         pragma Import (Ada, F1, "tool_doc_guards__finalize_body");
      begin
         E215 := E215 - 1;
         F1;
      end;
      E142 := E142 - 1;
      declare
         procedure F2;
         pragma Import (Ada, F2, "project_tools__release_checks__finalize_spec");
      begin
         F2;
      end;
      declare
         procedure F3;
         pragma Import (Ada, F3, "project_tools__files__finalize_body");
      begin
         E158 := E158 - 1;
         F3;
      end;
      declare
         procedure F4;
         pragma Import (Ada, F4, "ada__directories__finalize_body");
      begin
         E162 := E162 - 1;
         F4;
      end;
      declare
         procedure F5;
         pragma Import (Ada, F5, "ada__directories__finalize_spec");
      begin
         F5;
      end;
      E184 := E184 - 1;
      declare
         procedure F6;
         pragma Import (Ada, F6, "system__regexp__finalize_spec");
      begin
         F6;
      end;
      E200 := E200 - 1;
      declare
         procedure F7;
         pragma Import (Ada, F7, "system__pool_global__finalize_spec");
      begin
         F7;
      end;
      E121 := E121 - 1;
      declare
         procedure F8;
         pragma Import (Ada, F8, "ada__text_io__finalize_spec");
      begin
         F8;
      end;
      E144 := E144 - 1;
      declare
         procedure F9;
         pragma Import (Ada, F9, "ada__strings__unbounded__finalize_spec");
      begin
         F9;
      end;
      E204 := E204 - 1;
      declare
         procedure F10;
         pragma Import (Ada, F10, "system__storage_pools__subpools__finalize_spec");
      begin
         F10;
      end;
      E188 := E188 - 1;
      declare
         procedure F11;
         pragma Import (Ada, F11, "ada__streams__stream_io__finalize_spec");
      begin
         F11;
      end;
      declare
         procedure F12;
         pragma Import (Ada, F12, "system__file_io__finalize_body");
      begin
         E131 := E131 - 1;
         F12;
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
      if E191 = 0 then
         Gnat'Elab_Spec;
      end if;
      E191 := E191 + 1;
      if E240 = 0 then
         Interfaces.C.Strings'Elab_Spec;
      end if;
      E240 := E240 + 1;
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
      if E188 = 0 then
         Ada.Streams.Stream_Io'Elab_Spec;
      end if;
      E188 := E188 + 1;
      if E186 = 0 then
         System.Storage_Pools'Elab_Spec;
      end if;
      E186 := E186 + 1;
      if E204 = 0 then
         System.Storage_Pools.Subpools'Elab_Spec;
      end if;
      E204 := E204 + 1;
      if E144 = 0 then
         Ada.Strings.Unbounded'Elab_Spec;
      end if;
      E144 := E144 + 1;
      if E229 = 0 then
         System.Task_Info'Elab_Spec;
      end if;
      E229 := E229 + 1;
      if E164 = 0 then
         Ada.Calendar'Elab_Spec;
      end if;
      if E164 = 0 then
         Ada.Calendar'Elab_Body;
      end if;
      E164 := E164 + 1;
      if E170 = 0 then
         Ada.Calendar.Time_Zones'Elab_Spec;
      end if;
      E170 := E170 + 1;
      if E121 = 0 then
         Ada.Text_Io'Elab_Spec;
      end if;
      if E121 = 0 then
         Ada.Text_Io'Elab_Body;
      end if;
      E121 := E121 + 1;
      if E223 = 0 then
         System.Task_Primitives.Operations'Elab_Body;
      end if;
      E223 := E223 + 1;
      if E200 = 0 then
         System.Pool_Global'Elab_Spec;
      end if;
      E200 := E200 + 1;
      if E184 = 0 then
         System.Regexp'Elab_Spec;
      end if;
      E184 := E184 + 1;
      if E162 = 0 then
         Ada.Directories'Elab_Spec;
      end if;
      if E162 = 0 then
         Ada.Directories'Elab_Body;
      end if;
      E162 := E162 + 1;
      E194 := E194 + 1;
      if E158 = 0 then
         Project_Tools.Files'Elab_Body;
      end if;
      E158 := E158 + 1;
      E210 := E210 + 1;
      if E142 = 0 then
         Project_Tools.Release_Checks'Elab_Spec;
      end if;
      if E142 = 0 then
         Project_Tools.Release_Checks'Elab_Body;
      end if;
      E142 := E142 + 1;
      E236 := E236 + 1;
      if E215 = 0 then
         Tool_Doc_Guards'Elab_Spec;
      end if;
      if E215 = 0 then
         Tool_Doc_Guards'Elab_Body;
      end if;
      E215 := E215 + 1;
   end adainit;

   procedure Ada_Main_Program;
   pragma Import (Ada, Ada_Main_Program, "_ada_check_release_consistency");

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
   --   /home/bent/Projekte/Ada/version/tools/obj/tool_doc_guards.o
   --   /home/bent/Projekte/Ada/version/tools/obj/check_release_consistency.o
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
   --   -lgnarl
   --   -lgnat
   --   -lrt
   --   -lpthread
   --   -ldl
--  END Object file/option list   

end ada_main;
