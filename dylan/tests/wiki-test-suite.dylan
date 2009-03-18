module: wiki-test-suite

define test save-user-test ()
end;

define suite storage-test-suite ()
  test save-user-test;
end suite storage-test-suite;

define suite wiki-test-suite ()
  suite storage-test-suite;
end suite wiki-test-suite;

