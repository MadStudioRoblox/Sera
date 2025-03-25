--!strict
--!native

--[[
MAD STUDIO

-[Sera]---------------------------------------

	Low-level schematized serialization library

	Members:

		Sera.Boolean

		Sera.Uint8
		Sera.Uint16
		Sera.Uint32
		Sera.Int8
		Sera.Int16
		Sera.Int32
		Sera.Float32
		Sera.Float64

		Sera.CFrame -- 48 bytes; Full precision
		Sera.LossyCFrame -- 28 bytes; Less than 0.0005 degree precision error for rotation
		Sera.Vector3
		Sera.Color3
		Sera.ColorV3 -- Input and output are Vector3's with [0, 1] color values

		Sera.String8  -- Max 255 size
		Sera.String16 -- Max 65,535 size
		Sera.String32 -- Max 4,294,967,295 size

		Sera.Buffer8  -- Max 255 size
		Sera.Buffer16 -- Max 65,535 size
		Sera.Buffer32 -- Max 4,294,967,295 size
		
		Sera.Angle8 -- (Unsigned) Radian representation in one byte while preserving cardinal direction accuracy (Every 45 degrees)

	Functions:

		Sera.Schema(params): Schema -- Maximum 255 fields
			params:
				{
					["FieldName"]: SeraType,
					...
				}

		-- "Serialize", "Push", "DeltaSerialize" and "DeltaPush" will return first argument if succeeded,
		-- Or return an error message as the second argument if failed.

		-- When all fields are present (Non-schema fields are ignored; Missing fields will throw an error):

		Sera.Deserialize(schema: Schema, b: buffer, offset: number?): ({[string]: any}, offset: number)
		Sera.Serialize(schema: Schema, t: {[string]: any}): (buffer?, err: string?)
		Sera.Push(schema: Schema, t: {[string]: any}, b: buffer, offset: number?): (offset: number?, err: string?)

		-- When only some fields are present (Non-schema fields will throw an error):

		Sera.DeltaDeserialize(schema: Schema, b: buffer, offset: number?): ({[string]: any}, offset: number)
		Sera.DeltaSerialize(schema: Schema, t: {[string]: any}): (buffer?, err: string?)
		Sera.DeltaPush(schema: Schema, t: {[string]: any}, b: buffer, offset: number?): (offset: number?, err: string?)

		-- Delta serialization has an additional size cost of (n + 1) bytes where "n" is the number of fields present
		-- in a table that's being serialized (1 byte for present field count, 1 enumerating byte for each field)

--]]

local BIG_BUFFER_SIZE = 1000000 -- "Serialize" and "DeltaSerialize" will fail if resulting buffer size is larger than this value

local SIZE_8 = 2 ^ 8 - 1
local SIZE_16 = 2 ^ 16 - 1
local SIZE_32 = 2 ^ 32 - 1

local MAX_FIELDS = 2 ^ 8 - 1

local BB = buffer.create(BIG_BUFFER_SIZE) -- Big reusable buffer

----- Public -----

export type Ser = (b: buffer, offset: number, value: any) -> (number)
export type Des = (b: buffer, offset: number) -> (any, number)

export type SeraType = {
	Name: string,
	Ser: Ser,
	Des: Des,
}

type Field = {Key: string, Name: string, Ser: Ser, Des: Des, Index: number}

export type Schema = {
	Numeric: {Field},
	String: {[string]: Field},
}

local Sera = {
	BB = BB,
}

Sera.Boolean = table.freeze({
	Name = "Boolean",
	Ser = function(b: buffer, offset: number, value: boolean): number
		if value == true then
			buffer.writeu8(b, offset, 1)
		elseif value == false then
			buffer.writeu8(b, offset, 0)
		else
			error("Expected boolean")
		end
		return offset + 1
	end,
	Des = function(b: buffer, offset: number): (boolean, number)
		return buffer.readu8(b, offset) == 1, offset + 1
	end,
})

Sera.Uint8 = table.freeze({
	Name = "Uint8",
	Ser = function(b: buffer, offset: number, value: number): number
		buffer.writeu8(b, offset, value)
		return offset + 1
	end,
	Des = function(b: buffer, offset: number): (number, number)
		return buffer.readu8(b, offset), offset + 1
	end,
})

Sera.Uint16 = table.freeze({
	Name = "Uint16",
	Ser = function(b: buffer, offset: number, value: number): number
		buffer.writeu16(b, offset, value)
		return offset + 2
	end,
	Des = function(b: buffer, offset: number): (number, number)
		return buffer.readu16(b, offset), offset + 2
	end,
})

Sera.Uint32 = table.freeze({
	Name = "Uint32",
	Ser = function(b: buffer, offset: number, value: number): number
		buffer.writeu32(b, offset, value)
		return offset + 4
	end,
	Des = function(b: buffer, offset: number): (number, number)
		return buffer.readu32(b, offset), offset + 4
	end,
})

Sera.Int8 = table.freeze({
	Name = "Int8",
	Ser = function(b: buffer, offset: number, value: number): number
		buffer.writei8(b, offset, value)
		return offset + 1
	end,
	Des = function(b: buffer, offset: number): (number, number)
		return buffer.readi8(b, offset), offset + 1
	end,
})

Sera.Int16 = table.freeze({
	Name = "Int16",
	Ser = function(b: buffer, offset: number, value: number): number
		buffer.writei16(b, offset, value)
		return offset + 2
	end,
	Des = function(b: buffer, offset: number): (number, number)
		return buffer.readi16(b, offset), offset + 2
	end,
})

Sera.Int32 = table.freeze({
	Name = "Int32",
	Ser = function(b: buffer, offset: number, value: number): number
		buffer.writei32(b, offset, value)
		return offset + 4
	end,
	Des = function(b: buffer, offset: number): (number, number)
		return buffer.readi32(b, offset), offset + 4
	end,
})

Sera.Float32 = table.freeze({
	Name = "Float32",
	Ser = function(b: buffer, offset: number, value: number): number
		buffer.writef32(b, offset, value)
		return offset + 4
	end,
	Des = function(b: buffer, offset: number): (number, number)
		return buffer.readf32(b, offset), offset + 4
	end,
})

Sera.Float64 = table.freeze({
	Name = "Float64",
	Ser = function(b: buffer, offset: number, value: number): number
		buffer.writef64(b, offset, value)
		return offset + 8
	end,
	Des = function(b: buffer, offset: number): (number, number)
		return buffer.readf64(b, offset), offset + 8
	end,
})

Sera.CFrame = table.freeze({
	Name = "CFrame",
	Ser = function(b: buffer, offset: number, value: CFrame): number
		local v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11 = value:GetComponents()
		buffer.writef32(b, offset, v0)
		buffer.writef32(b, offset + 4, v1)
		buffer.writef32(b, offset + 8, v2)
		buffer.writef32(b, offset + 12, v3)
		buffer.writef32(b, offset + 16, v4)
		buffer.writef32(b, offset + 20, v5)
		buffer.writef32(b, offset + 24, v6)
		buffer.writef32(b, offset + 28, v7)
		buffer.writef32(b, offset + 32, v8)
		buffer.writef32(b, offset + 36, v9)
		buffer.writef32(b, offset + 40, v10)
		buffer.writef32(b, offset + 44, v11)
		return offset + 48
	end,
	Des = function(b: buffer, offset: number): (CFrame, number)
		return CFrame.new(
			buffer.readf32(b, offset),
			buffer.readf32(b, offset + 4),
			buffer.readf32(b, offset + 8),
			buffer.readf32(b, offset + 12),
			buffer.readf32(b, offset + 16),
			buffer.readf32(b, offset + 20),
			buffer.readf32(b, offset + 24),
			buffer.readf32(b, offset + 28),
			buffer.readf32(b, offset + 32),
			buffer.readf32(b, offset + 36),
			buffer.readf32(b, offset + 40),
			buffer.readf32(b, offset + 44)
		), offset + 48
	end,
})

Sera.LossyCFrame = table.freeze({
	Name = "LossyCFrame",
	Ser = function(b: buffer, offset: number, value: CFrame): number
		local axis, angle = value:ToAxisAngle()
		buffer.writef32(b, offset, value.X)
		buffer.writef32(b, offset + 4, value.Y)
		buffer.writef32(b, offset + 8, value.Z)
		buffer.writef32(b, offset + 12, axis.X)
		buffer.writef32(b, offset + 16, axis.Y)
		buffer.writef32(b, offset + 20, axis.Z)
		buffer.writef32(b, offset + 24, angle)
		return offset + 28
	end,
	Des = function(b: buffer, offset: number): (CFrame, number)
		return CFrame.fromAxisAngle(
			Vector3.new(
				buffer.readf32(b, offset + 12),
				buffer.readf32(b, offset + 16),
				buffer.readf32(b, offset + 20)
			),
			buffer.readf32(b, offset :: number + 24)
			)
			+ Vector3.new(
				buffer.readf32(b, offset),
				buffer.readf32(b, offset + 4),
				buffer.readf32(b, offset + 8)
			), offset + 28
	end,
})

Sera.Vector3 = table.freeze({
	Name = "Vector3",
	Ser = function(b: buffer, offset: number, value: Vector3): number
		buffer.writef32(b, offset, value.X)
		buffer.writef32(b, offset + 4, value.Y)
		buffer.writef32(b, offset + 8, value.Z)
		return offset + 12
	end,
	Des = function(b: buffer, offset: number): (Vector3, number)
		return Vector3.new(
			buffer.readf32(b, offset),
			buffer.readf32(b, offset + 4),
			buffer.readf32(b, offset + 8)
		), offset + 12
	end,
})

Sera.Color3 = table.freeze({
	Name = "Color3",
	Ser = function(b: buffer, offset: number, value: Color3): number
		buffer.writeu8(b, offset, value.R * 255)
		buffer.writeu8(b, offset + 1, value.G * 255)
		buffer.writeu8(b, offset + 2, value.B * 255)
		return offset + 3
	end,
	Des = function(b: buffer, offset: number): (Color3, number)
		return Color3.fromRGB(
			buffer.readu8(b, offset),
			buffer.readu8(b, offset + 1),
			buffer.readu8(b, offset + 2)
		), offset + 3
	end,
})

Sera.ColorV3 = table.freeze({
	Name = "ColorV3",
	Ser = function(b: buffer, offset: number, value: Vector3): number
		buffer.writeu8(b, offset, value.X * 255)
		buffer.writeu8(b, offset + 1, value.Y * 255)
		buffer.writeu8(b, offset + 2, value.Z * 255)
		return offset + 3
	end,
	Des = function(b: buffer, offset: number): (Vector3, number)
		return Vector3.new(
			buffer.readu8(b, offset) / 255,
			buffer.readu8(b, offset + 1) / 255,
			buffer.readu8(b, offset + 2) / 255
		), offset + 3
	end,
})

Sera.String8 = table.freeze({
	Name = "String8",
	Ser = function(b: buffer, offset: number, value: string): number
		local length = value:len()
		if length > SIZE_8 then
			error(`String too long`)
		end
		buffer.writeu8(b, offset, length)
		buffer.writestring(b, offset + 1, value)
		return offset + 1 + length
	end,
	Des = function(b: buffer, offset: number): (string, number)
		local length = buffer.readu8(b, offset)
		return buffer.readstring(b, offset + 1, length), offset + 1 + length
	end,
})

Sera.String16 = table.freeze({
	Name = "String16",
	Ser = function(b: buffer, offset: number, value: string): number
		local length = value:len()
		if length > SIZE_16 then
			error(`String too long`)
		end
		buffer.writeu16(b, offset, length)
		buffer.writestring(b, offset + 2, value)
		return offset + 2 + length
	end,
	Des = function(b: buffer, offset: number): (string, number)
		local length = buffer.readu16(b, offset)
		return buffer.readstring(b, offset + 2, length), offset + 2 + length
	end,
})

Sera.String32 = table.freeze({
	Name = "String32",
	Ser = function(b: buffer, offset: number, value: string): number
		local length = value:len()
		if length > SIZE_32 then
			error(`String too long`)
		end
		buffer.writeu32(b, offset, length)
		buffer.writestring(b, offset + 4, value)
		return offset + 4 + length
	end,
	Des = function(b: buffer, offset: number): (string, number)
		local length = buffer.readu32(b, offset)
		return buffer.readstring(b, offset + 4, length), offset + 4 + length
	end,
})

Sera.Buffer8 = table.freeze({
	Name = "Buffer8",
	Ser = function(b: buffer, offset: number, value: buffer): number
		local length = buffer.len(value)
		if length > SIZE_8 then
			error(`Buffer too long`)
		end
		buffer.writeu8(b, offset, length)
		buffer.copy(b, offset + 1, value)
		return offset + 1 + length
	end,
	Des = function(b: buffer, offset: number): (buffer, number)
		local length = buffer.readu8(b, offset)
		local value = buffer.create(length)
		buffer.copy(value, 0, b, offset + 1, length)
		return value, offset + 1 + length
	end,
})

Sera.Buffer16 = table.freeze({
	Name = "Buffer16",
	Ser = function(b: buffer, offset: number, value: buffer): number
		local length = buffer.len(value)
		if length > SIZE_16 then
			error(`Buffer too long`)
		end
		buffer.writeu16(b, offset, length)
		buffer.copy(b, offset + 2, value)
		return offset + 2 + length
	end,
	Des = function(b: buffer, offset: number): (buffer, number)
		local length = buffer.readu16(b, offset)
		local value = buffer.create(length)
		buffer.copy(value, 0, b, offset + 2, length)
		return value, offset + 2 + length
	end,
})

Sera.Buffer32 = table.freeze({
	Name = "Buffer32",
	Ser = function(b: buffer, offset: number, value: buffer): number
		local length = buffer.len(value)
		if length > SIZE_32 then
			error(`Buffer too long`)
		end
		buffer.writeu32(b, offset, length)
		buffer.copy(b, offset + 4, value)
		return offset + 4 + length
	end,
	Des = function(b: buffer, offset: number): (buffer, number)
		local length = buffer.readu32(b, offset)
		local value = buffer.create(length)
		buffer.copy(value, 0, b, offset + 4, length)
		return value, offset + 4 + length
	end,
})

do
	
	local rad2 = math.pi * 2
	local angle8range = math.rad(359)

	local function DegEncode(deg: number): number
		return math.round((deg % rad2) * 255 / angle8range)
	end

	local DegDecodeLookup: {number} = {}

	for i = 0, 255 do
		DegDecodeLookup[i] = i * angle8range / 255
	end

	for i = 0, 315, 45 do
		local r = math.rad(i)
		local index = DegEncode(r)
		DegDecodeLookup[index] = r
	end
	
	Sera.Angle8 = table.freeze({
		Name = "Angle8",
		Ser = function(b: buffer, offset: number, value: number): number
			buffer.writeu8(b, offset, DegEncode(value))
			return offset + 1
		end,
		Des = function(b: buffer, offset: number): (number, number)
			return DegDecodeLookup[buffer.readu8(b, offset)], offset + 1
		end,
	})
	
end

----

-- Returns dictionary of deserialized schema.
function Sera.Deserialize(schema: Schema, b: buffer, offset: number?): ({[string]: any}, number)

	offset = offset or 0
	local result = {}

	for _, field in schema.Numeric do
		result[field.Key], offset = field.Des(b, offset :: number)
	end

	return result, offset :: number

end

local function SerializeUnsafe(schema: Schema, t: {[string]: any}): number

	local offset = 0

	for _, field in schema.Numeric do
		offset = field.Ser(BB, offset, t[field.Key])
	end

	return offset

end

-- Returns new buffer of serialized schema or error message if fail.
function Sera.Serialize(schema: Schema, t: any): (buffer?, string?)

	local success, offset = pcall(SerializeUnsafe, schema, t)

	if not success then

		local ser_success
		offset = 0

		for _, field in schema.Numeric do

			local value = t[field.Key]

			if value ~= nil then
				ser_success, offset = pcall(field.Ser, BB, offset, value)
				if not ser_success then
					return nil, `Couldn't serialize field "{field.Key}" (Expected: {field.Name};Received: "{typeof(value)}"); Message: {offset}`
				end
			else
				return nil, `Missing field "{field.Key}"`
			end

		end

		return nil, `Unknown error`

	end

	local b = buffer.create(offset)
	buffer.copy(b, 0, BB, 0, offset)

	return b

end

local function PushUnsafe(schema: Schema, t: {[string]: any}, b: buffer, offset: number): number

	for _, field in schema.Numeric do
		offset = field.Ser(b, offset, t[field.Key])
	end

	return offset

end

-- Pushes serialized schema to an existing buffer; Returns new buffer offset or error message if fail.
function Sera.Push(schema: Schema, t: any, b: buffer, offset: number?): (number?, string?)

	offset = offset or 0
	local original_offset = offset :: number
	local success
	success, offset = pcall(PushUnsafe, schema, t, b, offset :: number)

	if not success then

		local ser_success
		offset = original_offset

		for _, field in schema.Numeric do

			local value = t[field.Key]

			if value ~= nil then
				ser_success, offset = pcall(field.Ser, b, offset :: number, value)
				if not ser_success then
					return nil, `Couldn't serialize field "{field.Key}" (Expected: {field.Name};Received: "{typeof(value)}"); Message: {offset}`
				end
			else
				return nil, `Missing field "{field.Key}"`
			end

		end

		return nil, `Unknown error`

	end

	return offset

end

-- Returns dictionary of deserialized deltas.
function Sera.DeltaDeserialize(schema: Schema, b: buffer, offset: number?): ({[string]: any}, number)

	offset = (offset or 0) + 1
	local field_count = buffer.readu8(b, offset :: number - 1)
	local result = {}

	local lookup = schema.Numeric

	for _ = 1, field_count do
		local field = lookup[buffer.readu8(b, offset :: number)]
		result[field.Key], offset = field.Des(b, offset :: number + 1)
	end

	return result, offset :: number

end

local function DeltaSerializeUnsafe(schema: Schema, t: {[string]: any}): number

	local field_count = 0
	local offset = 1

	local lookup = schema.String

	for key in t do
		field_count += 1
		local field = lookup[key]
		buffer.writeu8(BB, offset, field.Index)
		offset = field.Ser(BB, offset + 1, t[field.Key])
	end

	buffer.writeu8(BB, 0, field_count)

	return offset

end

-- Returns new buffer of serialized deltas or error message if fail.
function Sera.DeltaSerialize(schema: Schema, t: any): (buffer?, string?)

	local success, offset = pcall(DeltaSerializeUnsafe, schema, t)

	if not success then

		local ser_success
		offset = 1

		local lookup = schema.String

		for key, value in t do

			local field = lookup[key]

			if field == nil then
				return nil, `Key "{key}" not specified in schema`
			end

			buffer.writeu8(BB, offset, field.Index)
			ser_success, offset = pcall(field.Ser, BB, offset + 1, value)
			if not ser_success then
				return nil, `Couldn't serialize field "{field.Key}" (Expected: {field.Name};Received: "{typeof(value)}"); Message: {offset}`
			end

		end

		return nil, `Unknown error`

	end

	local b = buffer.create(offset)
	buffer.copy(b, 0, BB, 0, offset)

	return b

end

local function DeltaPushUnsafe(schema: Schema, t: {[string]: any}, b: buffer, offset: number): number

	local field_count = 0
	local start_offset = offset
	offset += 1

	local lookup = schema.String

	for key in t do
		field_count += 1
		local field = lookup[key]
		buffer.writeu8(b, offset, field.Index)
		offset = field.Ser(b, offset + 1, t[field.Key])
	end

	buffer.writeu8(b, start_offset, field_count)

	return offset

end

-- Pushes serialized deltas to an existing buffer; Returns new buffer offset or error message if fail.
function Sera.DeltaPush(schema: Schema, t: any, b: buffer, offset: number?): (number?, string?)

	offset = offset or 0
	local success
	success, offset = pcall(DeltaPushUnsafe, schema, t, b, offset :: number)

	if not success then

		local ser_success
		offset = 1

		local lookup = schema.String

		for key, value in t do

			local field = lookup[key]

			if field == nil then
				return nil, `Key "{key}" not specified in schema`
			end

			buffer.writeu8(b, offset :: number, field.Index)
			ser_success, offset = pcall(field.Ser, b, offset :: number + 1, value)
			if not ser_success then
				return nil, `Couldn't serialize field "{field.Key}" (Expected: {field.Name};Received: "{typeof(value)}"); Message: {offset}`
			end

		end

		return nil, `Unknown error`

	end

	return offset

end

function Sera.Schema(params: {[string]: SeraType}): Schema

	local fields: {Field} = {}

	for key, sera_type: SeraType in params do
		if typeof(key) ~= "string" then
			error(`[{script.Name}]: Expected string for field name; Received "{typeof(key)}"`)
		end
		if typeof(sera_type) ~= "table" or typeof(sera_type.Ser) ~= "function"
			or typeof(sera_type.Des) ~= "function" or typeof(sera_type.Name) ~= "string" then
			error(`[{script.Name}]: Expected SeraType for field "{key}"`)
		end
		table.insert(fields, {Key = key, Name = sera_type.Name, Ser = sera_type.Ser, Des = sera_type.Des, Index = 0})
	end

	if #fields == 0 then
		error(`[{script.Name}]: Schema must have fields`)
	end

	if #fields > MAX_FIELDS then
		error(`[{script.Name}]: Schema exceeded {MAX_FIELDS} fields; Received {#fields} fields`)
	end

	table.sort(fields, function(a, b)
		return a.Key < b.Key
	end)

	local string_fields: {[string]: Field} = {}

	for index, field in fields do
		field.Index = index
		string_fields[field.Key] = field
	end

	return table.freeze({
		Numeric = fields,
		String = string_fields,
	})

end

return Sera
