# Wanting a SSD for Digiline systems?
So here is the Datacard mod, SSD for Digiline! There are three types of datacards, that can store up to 800 datablocks. Punch a diskdrive with a datacard to insert it, and punch it again to take the datacard out.

## Digiline API
A request to the datacard diskdrive must be in table form:
```lua
{
	type = "read" or "write",
	data = ... -- only when type == "write"
}
```

### `type = "read"`
The response table would be like this:
```lua
{
	response_type = "read",
	success = true,
	data = ..., -- the data of the disk or nil
	used = 0, -- used datablocks
	capacity = 800, -- maximum usable datablocks
}
```

### `type = "write"`
The `data` field is required to store data, use `nil` to clear the data in a datacard.

The response table would be like this:
```lua
{
	response_type = "write",
	success = true,
	used = 0, -- used datablocks
	capacity = 800, -- maximum usable datablocks
}
```
### Errors
An error response is like this:
```lua
{
	response_type = "read" or "write",
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
