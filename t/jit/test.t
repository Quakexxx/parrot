#! parrot-nqp

# We want Test::More features for testing. Not NQP's builtin.
pir::load_bytecode("opsc.pbc");

# Some preparation
my $pir    := 't/compilers/opsc/data/02.pir';
my $pbc    := subst($pir, / 'pir' $/, 'pbc');

# Generate PBC file
my @args   := list("./parrot", "-o", $pbc, $pir);
my $res    := pir::spawnw__ip(@args);

# OpLib
my $oplib := pir::new__psp("OpLib", "core_ops");

# Parse "jitted.ops"
my $ops_file := Ops::File.new("t/jit/jitted.ops",
    :oplib($oplib),
    :core(0),
    :quiet(0),
);

my $jitter := Ops::JIT.new($pbc, $ops_file, $oplib);

my $start := 0;
my %jit_context := $jitter.jit($start);
my $module := %jit_context<_module>;
$module.verify();
#$module.dump();

# Create interp and seed it with bytecode
my $this_interp := pir::getinterp();
my $interp := func("make_interpreter", "ppi")($this_interp, 0);
func("Parrot_api_load_bytecode_file", "iPSP")($this_interp, $pbc, undef);

# "Invoke" target Sub inside target interp.
my $sub := Q:PIR{ %r = find_sub_not_null "main" };
my $pc;
$pc := func("Parrot_PMC_invoke", "ppPP")($interp, $sub, $pc);


# Some engine
my $engine := pir::new__psp("LLVM_Engine", $module);
my $call := $engine.create_call(%jit_context<jitted_sub>, "ppp");

# Go!
say("================= INVOKE ===================");
$pc := $call($pc, $interp);
say("=================  DONE  ===================");



sub func($name, $sig) {
    pir::dlfunc__ppss(undef, $name, $sig);
}

#%jit_context<_module>.dump();
# vim: ft=perl6
