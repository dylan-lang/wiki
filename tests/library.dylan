module: dylan-user

define library wiki-test-suite
  use common-dylan;
  use testworks;
  use wiki-internal;
end library wiki-test-suite;

define module wiki-test-suite
  use common-dylan;
  use testworks;
  use wiki-internal;
end module wiki-test-suite;
