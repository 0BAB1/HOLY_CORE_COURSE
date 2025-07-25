import os
import logging

import riscof.utils as utils
import riscof.constants as constants
from riscof.pluginTemplate import pluginTemplate

logger = logging.getLogger()

class holy_core(pluginTemplate):
    __model__ = "holy_core"
    __version__ = "0.0.1"

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        config = kwargs.get('config') # (from config.ini)

        if config is None:
            print("Please enter input file paths in configuration.")
            raise SystemExit(1)

        # In case of an RTL based DUT, this would be point to the final binary executable of your
        # test-bench produced by a simulator (like verilator, vcs, incisive, etc). In case of an iss or
        # emulator, this variable could point to where the iss binary is located. If 'PATH variable
        # is missing in the config.ini we can hardcode the alternate here.
        # BRH : in our case, its just the make command that we execute
        self.dut_exe = None # We use cocotb, no binary

        self.num_jobs = 1

        # Path to the directory where this python file is located. Collect it from the config.ini
        self.pluginpath=os.path.abspath(config['pluginpath'])

        # Collect the paths to the riscv-config absed ISA and platform yaml files. One can choose
        # to hardcode these here itself instead of picking it from the config.ini file.
        self.isa_spec = os.path.abspath(config['ispec'])
        self.platform_spec = os.path.abspath(config['pspec'])

        #We capture if the user would like the run the tests on the target or
        #not. If you are interested in just compiling the tests and not running
        #them on the target, then following variable should be set to False
        if 'target_run' in config and config['target_run']=='0':
            self.target_run = False
        else:
            self.target_run = True

    def initialise(self, suite, work_dir, archtest_env):

        # capture the working directory. Any artifacts that the DUT creates should be placed in this
        # directory. Other artifacts from the framework and the Reference plugin will also be placed
        # here itself.
        self.work_dir = work_dir

        # capture the architectural test-suite directory.
        self.suite_dir = suite

        # 0 : input file in assembly
        # 1 : ouput ELF
        # 2 : Compile macros
        # 3 : .bin file intermediary
        # 4 : end HEX DUMP file
        # 5 : testentry['isa'].lower()
        self.compile_cmd = 'riscv64-unknown-elf-gcc -march={5} -mabi=ilp32 \
            -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles -g\
            -T '+self.pluginpath+'/env/link.ld\
            -I '+self.pluginpath+'/env/\
            -I ' + archtest_env + ' {0} -o {1} {2}\
            \
            ;\
            \
            riscv64-unknown-elf-objcopy -O binary {1} {3} \
            \
            ;\
            \
            hexdump -v -e \'1/4 \"%08x\\n\"\' {3} > {4}\
            '

        # add more utility snippets here.
        # BRH : No. Thank you

    def build(self, isa_yaml, platform_yaml):
        # We don't need any build for the holy core : We use cocotb.
        # or maybe execut make once for cocotb to build 1st time, idk
        pass

    def runTests(self, testList):

        # Delete Makefile if it already exists.
        if os.path.exists(self.work_dir+ "/Makefile." + self.name[:-1]):
            os.remove(self.work_dir+ "/Makefile." + self.name[:-1])
        # create an instance the makeUtil class that we will use to create targets.
        make = utils.makeUtil(makefilePath=os.path.join(self.work_dir, "Makefile." + self.name[:-1]))

        # set the make command that will be used. The num_jobs parameter was set in the __init__
        # function earlier
        make.makeCommand = 'make -k -j' + str(self.num_jobs)

        print("make init okay")

        # we will iterate over each entry in the testList. Each entry node will be refered to by the
        # variable testname.
        for testname in testList:
            print("configuring test commands for " + str(testname))

            # for each testname we get all its fields (as described by the testList format)
            testentry = testList[testname]

            # we capture the path to the assembly file of this test
            test = testentry['test_path']

            # capture the directory where the artifacts of this test will be dumped/created. RISCOF is
            # going to look into this directory for the signature files
            test_dir = testentry['work_dir']

            # name of the files generated (elf, bin, hex)
            elf = 'my.elf'
            bin = 'my.bin'
            hex = 'my.hex'

            # name of the signature file as per requirement of RISCOF. RISCOF expects the signature to
            # be named as DUT-<dut-name>.signature. The below variable creates an absolute path of
            # signature file.
            sig_file = os.path.join(test_dir, self.name[:-1] + ".signature")

            # for each test there are specific compile macros that need to be enabled. The macros in
            # the testList node only contain the macros/values. For the gcc toolchain we need to
            # prefix with "-D". The following does precisely that.
            compile_macros= ' -D' + " -D".join(testentry['macros'])
            
            # 0 : input file in assembly
            # 1 : ouput ELF
            # 2 : Compile macros
            # 3 : .bin file intermediary
            # 4 : end HEX DUMP file
            # 5 : testentry['isa'].lower()
            comp_cmd = self.compile_cmd.format(
                test,
                elf, 
                compile_macros,
                bin,
                hex,
                testentry['isa'].lower()
            )


            # get symbol list from elf file
            nm_symbols_cmd = f'riscv32-unknown-elf-nm {elf} > dut.symbols'

            # extract listed symbols
            symbols_list = ['begin_signature', 'end_signature','write_tohost', 'tohost', 'fromhost']
            # construct dictionary of listed symbols
            symbols_cmd = []
            symbols_cmd.append(nm_symbols_cmd)
            for symbol in symbols_list:
                # get symbols from symbol list file
                cmd = f'export {symbol}=$$(grep -w {symbol} dut.symbols | cut -c 1-8)'
                symbols_cmd.append(cmd)

            # if the user wants to disable running the tests and only compile the tests, then
            # the "else" clause is executed below assigning the sim command to simple no action
            # echo statement.
            if self.target_run:
                # We go in the tb's dir
                simcmd = 'cd {0} && '.format(os.path.join(self.pluginpath, "../holy_core_tb/"))
                # execute make (tb) and specify init memory content + symbols addresses
                simcmd += 'IHEX_PATH="{0}" make > tb_messages.log;'.format(os.path.join(test_dir, hex))
                # And finally, copy paste the waveforms in the work dir
                simcmd += 'cp ./dump.vcd {0};'.format(testentry['work_dir'])
                simcmd += 'cp ./dut.log {0};'.format(testentry['work_dir'])
                simcmd += 'cp {0} {1};'.format(sig_file ,testentry['work_dir'])
                simcmd += 'cp ./tb_messages.log {0}'.format(testentry['work_dir'])
            else:
                simcmd = 'echo "NO RUN"'

            execute = []
            execute.append(f'cd {testentry["work_dir"]}')
            execute.append(comp_cmd)
            execute += symbols_cmd
            execute.append(simcmd)

            # create a target. The makeutil will create a target with the name "TARGET<num>" where num
            # starts from 0 and increments automatically for each new target that is added
            make.add_target('@' + ';\\\n'.join(execute))

        # if you would like to exit the framework once the makefile generation is complete uncomment the
        # following line. Note this will prevent any signature checking or report generation.
        #raise SystemExit

        # once the make-targets are done and the makefile has been created, run all the targets in
        # parallel using the make command set above.
        print("Executing tests commands " + str(testname))
        make.execute_all(self.work_dir)

        # if target runs are not required then we simply exit as this point after running all
        # the makefile targets.
        if not self.target_run:
            raise SystemExit(0)