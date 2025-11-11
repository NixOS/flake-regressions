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

          in

          rec {

            allSchemas = (flake.outputs.schemas or defaultSchemas) // schemaOverrides;

            # FIXME: make this configurable
            defaultSchemas =
              (builtins.getFlake "https://api.flakehub.com/f/pinned/DeterminateSystems/flake-schemas/0.2.0/019a4a84-544d-7c59-b26d-e334e320c932/source.tar.gz?narHash=sha256-eK3/xbUOrxp9fFlei09XNjqcdiHXxndzrTXp7jFpOk8%3D")
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
                    attrs:
                    if filterFun attrs then
                      if attrs ? children then
                        mkChildren (builtins.mapAttrs (childName: child: doFilter child) attrs.children)
                      else
                        (if attrs ? what then { inherit (attrs) what; } else { })
                        // (if attrs ? forSystems then { inherit (attrs) forSystems; } else { })
                        // (if attrs ? shortDescription then { inherit (attrs) shortDescription; } else { })
                        // (
                          if inputs.self.includeOutputPaths && attrs ? derivation then
                            {
                              derivation = {
                                name = attrs.derivation.name;
                                path = builtins.unsafeDiscardStringContext attrs.derivation.drvPath;
                                outputs = builtins.listToAttrs (
                                  builtins.map (outputName: {
                                    name = outputName;
                                    value = attrs.derivation.${outputName}.outPath;
                                  }) attrs.derivation.outputs
                                );
                              };
                            }
                          else
                            { }
                        )
                    else
                      { };
                in
                # Ignore legacyPackages for now, since it's very big and throws uncatchable errors.
                if outputName == "legacyPackages" then
                  {
                    skipped = true;
                  }
                else
                  {
                    doc = schema.doc;
                    output = doFilter ((schema.inventory or (output: { })) flake.outputs.${outputName});
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
