# Riscof compliance check

> Note : you can now run compliance checks easily using the docker image, without having to worry about what's in there. See user guide below.

This folder contains :

- A specific testbench to load riscof tests programs on the holycore testbench
- Riscof config yaml file to specify what we want to test
- A plugin explaining :
  - How to oinfigure the tests
  - How to compile the tests programs to fit our tb's needs
  - How to run the tests

## User guide: Containerized compliance tests

Because settinp up compliance tests is a real pain, the end user can simply build a docker image and run compliance tests easily after each significant modification (or just to make sure the holy core works).

### Prerequisites

- docker

### Commands

Cd into the edition (e.g. `<root>/2_soc_software_edition/`) and build the image using the following:

```bash
$ docker build -t riscof-runner . 
```

Using the local file (which would include any modification you made etc...), this will create a containerized testing environement that you can use to run any test, including lighter ones used for developement in the `tb/` folder. But it also mailny embeds everything you need to run the riscof complioance checks.

Once the image is built, to run the tests, simply launch a container form the image:

```bash
$ docker run -it riscof-runner bash
```

And, once in the container, run the tests using:

```bash
(test container) $ riscof riscof validateyaml 
```

to generate validated yamls of the isa and platform, then :

```bash
(test container) $ riscof gendb --suite=riscv-arch-test/riscv-test-suite/ --env=riscv-arch-test/riscv-test-suite/env
```

to gen atest db, then:

```bash
(test container) $ riscof gendb --suite=riscv-arch-test/riscv-test-suite/ --env=riscv-arch-test/riscv-test-suite/env
```

to run the tests using a selection of tests.

### Debugging tips

Debugging the compliance test is a proces detailled in the holy core course's docs themselves. To retrive files for debugging, use the following command:

```bash
docker cp <contianer_name_or_id>:/compliance_test/riscof/riscof_work ./output
```

## User guide: Detailed compliance tests setup

> **WARNING :** deprecated, see container procedure above and mix it toghether...

### Prerequisites

> Notes that you won't use these tools directly, it all happens "under the hood".

The golden reference used here is Spike. You have a guide on how to install it here : [Link to riscof guide](https://riscof.readthedocs.io/en/latest/installation.html#install-plugin-models).

Then, you will need the **riscv32 toolchain** to compile the test programs and `hexdump` that will convert the compile program fot he holy core tesbench
platform into an hex we can load in the simulated memory.

Finally, you will need to install `riscof` here : [Link to riscof guide](https://riscof.readthedocs.io/en/latest/installation.html) in an adapted python environment.

### Commands

> to use riscof, you'll need to pyenv in the python's 3.6.15 version. Yes this is bad but that's how it is.

1. cd into the `./2_soc_software_edition/riscof/` folder.
2. run `riscof --verbose info arch-test --clone` to download the assembly test programs
3. run `riscof run --config=config.ini --suite=riscv-arch-test/riscv-test-suite/ --env=riscv-arch-test/riscv-test-suite/env`

This final command will check what tests are needed (using the *yaml* config file) and compile / run these tests (using our `riscof_holy_core.py` plugin).

The test platform is a cocotb testbench with

- The core itself
- A simple wrapper around the core that demuxes the SystemVerilog interface into traditional Verilog signals
- Memory peripherals simulated by `cocotbext.axi` ([a simple cocotb way to have some memory](https://github.com/alexforencich/cocotbext-axi))

### Known problems with compliance tests

- Signature may fail to generate, this may be due to Verilator and Cocotb not building because of some old builds remainings causing some conflicts that I personnally don't understand.
- To debug what happened, check out test results and various logs in the `riscof_work` test's folder, you'll see spike like logs of the test execution, cocotb messages logs and more.
- The solution is to run the `make clean` command in the `riscof/` folder and try again.
- Also watch out for python environements ! Your cocotb and riscof installs may not work on the same python version / environments (like mine). This is a big pain to setup as well (takes half a day more or less depending on how lucky you are). cocotb and verilator also need to be on the same page in terms of versions, sometime, updates can mess everything up. Fututre work would include a nice docker container but I'm procrastinating this.
