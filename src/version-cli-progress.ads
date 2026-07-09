with Version.Progress;

package Version.CLI.Progress is

   type Stderr_Sink is new Version.Progress.Sink with null record;

   overriding procedure Message
     (Item : in out Stderr_Sink;
      Text : String);

end Version.CLI.Progress;
