module: dylan-user

define library wiki-test-suite
  use common-dylan;
  use testworks;
  use wiki;

  export wiki-test-suite;
end library wiki-test-suite;

define module wiki-test-suite
  use common-dylan;
  use testworks;
  use wiki-internal;

  export wiki-test-suite;
end module wiki-test-suite;
