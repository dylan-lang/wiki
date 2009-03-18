module: dylan-user
author: turbo24prg

define library wiki
  use collections;
  use common-dylan,
    import: { common-extensions };
  use dylan;
  use http-common;
  use io;
  use koala,
    import: { dsp };
  use network;
  use strings;
  use string-extensions;
  use system,
    import: { locators, threads, date, file-system };
  use regular-expressions;
  use uri;
  use web-framework;
  use xml-parser;
  use xml-rpc-client;

  use source-location;
  use grammar;
  use simple-parser;
  use regular;

  use graphviz-renderer;

  // for the test suite
  export wiki-internal;
end library wiki;

define module wiki-internal
  use changes,
    exclude: { <uri> };
  use common-extensions,
    exclude: { format-to-string };
  use date;
  use dsp;
  use dylan;
  use file-system;
  use format;
  use format-out;
  use http-common,
    exclude: { remove-attribute };
  use locators,
    import: { <file-locator>,
              locator-name,
              merge-locators };
  use permission;
  use simple-xml;
  use storage;
  use streams;
  use strings,
    import: { index-of };
  use substring-search;
  use table-extensions;
  use threads;
  use regular-expressions;
  use uri;
  use users;
  use web-framework,
    exclude: { slot-type };
  use xml-parser,
    prefix: "xml/";
  use xml-rpc-client;

  // for the parser
  use simple-parser;
  use source-location;
  use source-location-rangemap;
  use grammar;
  use simple-lexical-scanner;

  use graphviz-renderer,
    prefix: "gvr/";
end module wiki-internal;

