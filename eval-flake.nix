{
  inputs.flake.url = "c9026fc0-ced9-48e0-aa3c-fc86c4c86df1";
  outputs = inputs: {
    includeOutputPaths = true;

    contents =
      let
        getFlakeOutputs =
          flake:
          let

            # Helper functions.

            mapAttrsToList = f: attrs: map (name: f name attrs.${name}) (builtins.attrNames attrs);

            try =
              e: default:
              let
                res = builtins.tryEval e;
              in
              if res.success then res.value else default;

            mkChildren = children: { inherit children; };

            getAttrFromPath =
              attrPath: set:
              let
                f =
                  n: set: if n >= builtins.length attrPath then set else f (n + 1) set.${builtins.elemAt attrPath n};
              in
              f 0 set;

          in

          rec {

            allSchemas = (flake.outputs.schemas or defaultSchemas) // schemaOverrides;

            # FIXME: make this configurable
            defaultSchemas =
              (builtins.getFlake "https://api.flakehub.com/f/pinned/DeterminateSystems/flake-schemas/0.4.0/019cfd60-4ae2-753f-8f8a-d718c39f31ed/source.tar.gz?narHash=sha256-ncGXLsh87OYfoF5zmtIY9GK217VaE6nwaNYPGZMrL8c%3D")
              .schemas;

            schemaOverrides = { };

            schemas = builtins.listToAttrs (
              builtins.concatLists (
                mapAttrsToList (
                  outputName: output:
                  if allSchemas ? ${outputName} then
                    [
                      {
                        name = outputName;
                        value = allSchemas.${outputName};
                      }
                    ]
                  else
                    [ ]
                ) flake.outputs
              )
            );

            uncheckedOutputs = builtins.filter (outputName: !schemas ? ${outputName}) (
              builtins.attrNames flake.outputs
            );

            inventoryFor =
              filterFun:
              builtins.mapAttrs (
                outputName: schema:
                let
                  doFilter =
                    outputInfo: output:
                    if filterFun outputInfo then
                      if outputInfo ? isLegacy then
                        {
                          isLegacy = true;
                        }
                      else if outputInfo ? children then
                        mkChildren (
                          builtins.mapAttrs (childName: child: doFilter child output.${childName}) outputInfo.children
                        )
                      else
                        (if outputInfo ? what then { inherit (outputInfo) what; } else { })
                        // (if outputInfo ? forSystems then { inherit (outputInfo) forSystems; } else { })
                        // (if outputInfo ? shortDescription then { inherit (outputInfo) shortDescription; } else { })
                        // (
                          # FIXME: remove outputInfo.derivation support eventually.
                          if
                            inputs.self.includeOutputPaths && (outputInfo ? derivationAttrPath || outputInfo ? derivation)
                          then
                            let
                              drv = outputInfo.derivation or (getAttrFromPath outputInfo.derivationAttrPath output);
                            in
                            {
                              derivation = {
                                name = drv.name;
                                path = builtins.unsafeDiscardStringContext drv.drvPath;
                                outputs = builtins.listToAttrs (
                                  builtins.map (outputName: {
                                    name = outputName;
                                    value = drv.${outputName}.outPath;
                                  }) drv.outputs
                                );
                              };
                            }
                          else
                            { }
                        )
                    else
                      { };
                in
                {
                  doc = schema.doc;
                  output = doFilter ((schema.inventory or (output: { }))
                    flake.outputs.${outputName}
                  ) flake.outputs.${outputName};
                }
              ) schemas;

            inventory =
              inventoryFor (x: true)
              // builtins.listToAttrs (
                map (name: {
                  inherit name;
                  value = {
                    unknown = true;
                  };
                }) uncheckedOutputs
              );

            contents = {
              version = 2;
              inherit inventory;
            };

          };
      in
      (getFlakeOutputs inputs.flake).contents;
  };
}
