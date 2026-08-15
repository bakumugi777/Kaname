# Shared-shell example

Quickshell resolves local modules from inside the active configuration
directory. Prepare a local `Kaname` link before running this example:

```bash
ln -s ../../quickshell examples/shared-shell/Kaname
quickshell -p "$PWD/examples/shared-shell" --daemonize
KANAME_QML_DIR="$PWD/examples/shared-shell" ./bin/kaname --applications
```

Stop only this example instance with:

```bash
quickshell kill -p "$PWD/examples/shared-shell"
```

The `Kaname` link is ignored by Git. In a Home Manager configuration, use an
`xdg.configFile` source instead of creating the link manually.
