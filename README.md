# Explosive Gaming for Clusterio

This is a plugin collection for [Clusterio](https://github.com/clusterio/clusterio) which provides all our scenario features.

## Installation 

To use this plugin you must already have a clusterio instance running, see [here](https://github.com/clusterio/clusterio?tab=readme-ov-file#installation) for clusterio installation instructions.

This module is currently not published and therefore can not be installed via `npm`. Instead follow the steps for [building from source](#building-from-source)

## Building from source

1) Create a `external_plugins` directory within your clustorio instance.
2) Clone this repository into that directory: `git clone https://github.com/explosivegaming/ExpCluster`
3) Install the package dev dependencies: `pnpm install`
4) Add the plugins to your clustorio instance such as: `node ./packages/controller plugin add ./external_plugins/ExpCluster/exp_groups`

## Contributing 

See [Contributing](CONTRIBUTING.md) for how to make pull requests and issues.
