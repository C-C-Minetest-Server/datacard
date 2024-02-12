# Wanting a SSD for Digiline systems?

So here is the Datacard mod, SSD for Digiline! There are three types of datacards, that can store up to 800 datablocks. Punch a diskdrive with a datacard to insert it, and punch it again to take the datacard out.

## Messages sent by the diskdrive

### `responce_type = "inject"`

Sent when a datacard is injected into a diskdrive.

```lua
{
	responce_type = "inject",
}
```

### `responce_type = "eject"`

Sent when a datacard is ejected, either because a user punched it, or [requested by another digiline signal](#type--eject).

```lua
{
	responce_type = "eject",
	id = ..., -- Only when requested via digiline
}
```

## Digiline API

A request to the datacard diskdrive must be in table form:

```lua
{
	type = "read" or "write",
	data = ..., -- only when type == "write"
	id   = ..., -- Kept intact in every responces
}
```

In every responces, including the error ones, the ID will be kept.

### `type = "read"`

The responce table would be like this:

```lua
{
	responce_type = "read",
	success = true,
	data = ..., -- the data of the disk or nil
	used = 0, -- used datablocks
	capacity = 800, -- maximum usable datablocks
}
```

### `type = "write"`

The `data` field is required to store data, use `nil` to clear the data in a datacard.

The responce table would be like this:

```lua
{
	responce_type = "write",
	success = true,
	used = 0, -- used datablocks
	capacity = 800, -- maximum usable datablocks
}
```

### `type = "eject"`

This type of request ejects the datacard.

A normal eject responce will be returned.

### Errors

An error responce is like this:

```lua
{
	responce_type = "read" or "write",
	success = false,
	error = "ERROR_CODE",
}
```

#### Error Codes

* **`TOO_BIG`**: The data is too big for the datacard inserted into the diskdrive.<br>*Appear only on `write` requests*
* **`ERR_SERIALIZE`**: A serialize bug happened. A possible reason is that the data is too large for the engine to handle.<br>*Appear only on `write` requests*
* **`NO_DISK`**: There are no datacards in the diskdrive.
* **`UNKNOWN_CMD`**: The `type` value is not `"read"` or `"write"`.

## License

The code are avaliable under the MIT License. Textures from [Malcolm Riley's Unused Textures](https://github.com/malcolmriley/unused-textures), and are avaliable under [CC BY-SA 4.0](https://creativecommons.org/licenses/by/4.0/).
