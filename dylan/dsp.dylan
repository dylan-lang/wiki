Module: wiki-internal

define taglib wiki () end;

// Represents a DSP maintained in our source code tree. Not to be confused
// with <wiki-page>, which is a user-editable wiki page stored in the database
// by web-framework.
//
define class <wiki-dsp> (<dylan-server-page>)
end;

