Module: dylan-user

define library wiki-test-suite
  use common-dylan;
  use system;
  use testworks;
  use wiki;

  export wiki-test-suite;
end library wiki-test-suite;

define module wiki-test-suite
  use common-dylan;
  use locators,
    import: { <file-locator>, locator-name };
  use operating-system,
    import: { application-name };
  use testworks;
  use wiki-internal;

  export wiki-test-suite;
end module wiki-test-suite;
