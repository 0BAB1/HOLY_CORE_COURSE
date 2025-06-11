# Riscof compliance check

this folder contains :

- A specific testbench to load riscof tests programs on the holycore testbench
- Riscof config yaml file to specify what we want to test
- A plugin explaining :
  - How to cinfigure the tests
  - How to compile the tests programs to fit our tb's needs
  - How to run the tests

## User guide : Run compliance tests

1. Get the tests : `riscof --verbose info arch-test --clone`
2. 