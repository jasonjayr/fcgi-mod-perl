#!/usr/bin/perl
use lib './lib/';
use FCGI::MPEmulator;
use FCGI::ModPerl13;

exit FCGI::MPEmulator->run(FCGI::ModPerl13);
