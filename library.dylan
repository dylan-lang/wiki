module: dylan-user
author: turbo24prg

define library wiki
  use dylan;
  use common-dylan,
    import: { common-extensions };
  use io;
  use system,
    import: { locators, threads, date, file-system };
  use network;
  use collections;
  use strings;
  use string-extensions;
  use regular-expressions;
  use koala,
    import: { dsp };
  use web-framework;
  use xml-parser;
  use xml-rpc-client;
  use uri;

  use source-location;
  use grammar;
  use simple-parser;
  use regular;

  use graphviz-renderer;
end;

define module wiki
  use dylan;
  use threads;
  use common-extensions,
    exclude: { format-to-string };
  use locators;
  use file-system;
  use date;
  use format;
  use format-out;
  use table-extensions;
  use sockets;
  use streams;
  use character-type;
  use substring-search;
  use strings, import: { index-of, case-insensitive-equal? };
  use regular-expressions;
  use dsp, exclude: { join };
  use web-framework, exclude: { slot-type };
  use users;
  use storage;
  use changes;
  use permission;
  use xml-parser, 
    rename: { <comment> => <xml-comment>, 
              name => xml-name, 
              name-setter => xml-name-setter };
  use simple-xml;
  use xml-rpc-client;
  use uri;

  use simple-parser;
  use source-location;
  use source-location-rangemap;
  use grammar;
  use simple-lexical-scanner;

  use graphviz-renderer;
end;
