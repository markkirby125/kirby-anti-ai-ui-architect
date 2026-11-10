#!/usr/bin/env node
import { Command } from 'commander';

const program = new Command();
program.name('report').argument('<file>').action((file) => console.log(`reading ${file}`));
program.parse();
