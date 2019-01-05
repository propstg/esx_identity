ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

function getIdentity(source, callback)
	local identifier = GetPlayerIdentifiers(source)[1]

	MySQL.Async.fetchAll('SELECT identifier, firstname, lastname, dateofbirth, sex, height, skin FROM `users` WHERE `identifier` = @identifier', {
		['@identifier'] = identifier
	}, function(result)
		if result[1].firstname ~= nil then
			callback({
				identifier	= result[1].identifier,
				character = result[1]
			})
		else
			callback({
				identifier	= '',
				firstname	= '',
				lastname	= '',
				dateofbirth	= '',
				sex			= '',
				height		= '',
				skin		= nil
			})
		end
	end)
end

function getCharacters(source, callback)
	local identifier = GetPlayerIdentifiers(source)[1]
	MySQL.Async.fetchAll('SELECT * FROM `characters` WHERE `identifier` = @identifier', {
		['@identifier'] = identifier
	}, function(result)
		callback({
			identifier = identifier,
			characters = result
		})
	end)
end

function setIdentity(identifier, data, callback)
	local params = createParams(identifier, data.character)

	MySQL.Async.execute(
		'INSERT INTO characters (identifier, firstname, lastname, dateofbirth, sex, height, skin) VALUES (@identifier, @firstname, @lastname, @dateofbirth, @sex, @height, @skin)', 
		params,
		function(result)
			MySQL.Async.fetchAll('SELECT max(id) as insertedId FROM characters WHERE identifier = @identifier', params, function(insertedId)
				data.character.id = insertedId[1].insertedId
				updateIdentity(identifier, data, callback)
			end)
		end
	)
end

function updateIdentity(identifier, data, callback)
	MySQL.Async.execute(
		'UPDATE `users` SET '..
		'`firstname` = @firstname, ' ..
		'`lastname` = @lastname, ' ..
		'`dateofbirth` = @dateofbirth, ' ..
		'`sex` = @sex, ' ..
		'`height` = @height, ' ..
		'`skin` = @skin, ' ..
		'`current_character_id` = @characterId ' ..
		'WHERE identifier = @identifier',
		createParams(identifier, data.character),
		function(rowsChanged)
			if callback then
				callback(true)
			end
		end
	)
end

function deleteIdentity(identifier, data, callback)
	MySQL.Async.execute(
		'DELETE FROM `characters` WHERE identifier = @identifier AND id = @characterId',
		createParams(identifier, data.character),
		function(rowsChanged)
			if callback then
				callback(true)
			end
		end
	)
end

function createParams(identifier, character)
	return {
		['@identifier']		= identifier,
		['@firstname']		= character.firstname,
		['@lastname']		= character.lastname,
		['@dateofbirth']	= character.dateofbirth,
		['@sex']			= character.sex,
		['@height']			= character.height,
		['@skin']			= character.skin,
		['@characterId']	= character.id
	}
end

RegisterServerEvent('esx_skin:save')
AddEventHandler('esx_skin:save', function(skin)
	local xPlayer = ESX.GetPlayerFromId(source)

	MySQL.Async.execute('UPDATE characters SET `skin` = @skin WHERE identifier = @identifier AND `id` = (SELECT current_character_id FROM `users` WHERE identifier = @identifier)',
	{
		['@skin']		= json.encode(skin),
		['@identifier'] = xPlayer.identifier
	})
end)

RegisterServerEvent('esx_identity:setIdentity')
AddEventHandler('esx_identity:setIdentity', function(data, myIdentifiers)
	setIdentity(myIdentifiers.steamid, data, function(callback)
		if callback then
			TriggerClientEvent('esx_identity:identityCheck', myIdentifiers.playerid, true)
		else
			TriggerClientEvent('chat:addMessage', source, { args = { '^[IDENTITY]', 'Failed to set character, try again later or contact the server admin!' } })
		end
	end)
end)

AddEventHandler('es:playerLoaded', function(source)
	local myID = {
		steamid = GetPlayerIdentifiers(source)[1],
		playerid = source
	}

	TriggerClientEvent('esx_identity:saveID', source, myID)
	getIdentity(source, function(data)
		if data.character.firstname == '' then
			TriggerClientEvent('esx_identity:identityCheck', source, false)
			TriggerClientEvent('esx_identity:showRegisterIdentity', source)
		else
			TriggerClientEvent('esx_identity:identityCheck', source, true)
		end
	end)
end)

AddEventHandler('onResourceStart', function(resource)
	if resource == GetCurrentResourceName() then
		Citizen.Wait(3000)

		-- Set all the client side variables for connected users one new time
		local xPlayers, xPlayer = ESX.GetPlayers()
		for i=1, #xPlayers, 1 do
			xPlayer = ESX.GetPlayerFromId(xPlayers[i])

			local myID = {
				steamid  = xPlayer.identifier,
				playerid = xPlayer.source
			}

			TriggerClientEvent('esx_identity:saveID', xPlayer.source, myID)

			getIdentity(xPlayer.source, function(data)
				if data.character.firstname == '' then
					TriggerClientEvent('esx_identity:identityCheck', xPlayer.source, false)
					TriggerClientEvent('esx_identity:showRegisterIdentity', xPlayer.source)
				else
					TriggerClientEvent('esx_identity:identityCheck', xPlayer.source, true)
				end
			end)
		end
	end
end)

TriggerEvent('es:addCommand', 'register', function(source, args, user)
	getCharacters(source, function(data)
		if #data.characters >= Config.MaxCharacters then
			TriggerClientEvent('chat:addMessage', source, { args = { '^[IDENTITY]', 'You can only have '..Config.MaxCharacters..' registered characters. Use the ^3/chardel^0  command in order to delete existing characters.' } })
		else
			TriggerClientEvent('esx_identity:showRegisterIdentity', source, {})
		end
	end)
end, {help = "Register a new character"})

TriggerEvent('es:addGroupCommand', 'char', 'user', function(source, args, user)
	getIdentity(source, function(data)
		if data.character.firstname == '' then
			TriggerClientEvent('chat:addMessage', source, { args = { '^1[IDENTITY]', 'You do not have an active character!' } })
		else
			TriggerClientEvent('chat:addMessage', source, { args = { '^1[IDENTITY]', 'Active character: ^2' .. data.character.firstname .. ' ' .. data.character.lastname } })
		end
	end)
end, function(source, args, user)
	TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'Insufficient permissions!' } })
end, {help = "List your current character"})

TriggerEvent('es:addGroupCommand', 'charlist', 'user', function(source, args, user)
	getCharacters(source, function(data)
		if #data.characters > 0 then
			for index, character in pairs(data.characters) do
				TriggerClientEvent('chat:addMessage', source, { args = { '^1[IDENTITY] Character ' .. index .. ':', character.firstname .. ' ' .. character.lastname } })
			end
		else
			TriggerClientEvent('chat:addMessage', source, { args = { '^[IDENTITY]', 'You have no registered characters. Use the ^3/register^0 command to register a character.' } })
		end
	end)
end, function(source, args, user)
	TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'Insufficient permissions!' } })
end, {help = "List all your registered characters"})

TriggerEvent('es:addGroupCommand', 'charselect', 'user', function(source, args, user)
	local charNumber = tonumber(args[1])

	if charNumber == nil or charNumber > Config.MaxCharacters or charNumber < 1 then
		TriggerClientEvent('chat:addMessage', source, { args = { '^[IDENTITY]', 'That\'s an invalid character!' } })
		return
	end

	getCharacters(source, function(data)
		if #data.characters < charNumber then
			TriggerClientEvent('chat:addMessage', source, { args = { '^1[IDENTITY]', 'You don\'t have a character in slot ' .. charNumber .. '!' } })
		else
			local data = {
				identifier	= data.identifier,
				character = data.characters[charNumber]
			}

			updateIdentity(GetPlayerIdentifiers(source)[1], data, function(callback)
				if callback then
					TriggerClientEvent('skinchanger:loadSkin', source, json.decode(data.character.skin), nil)
					TriggerClientEvent('chat:addMessage', source, { args = { '^1[IDENTITY]', 'Updated your active character to ^2' .. data.character.firstname .. ' ' .. data.character.lastname } })
				else
					TriggerClientEvent('chat:addMessage', source, { args = { '^1[IDENTITY]', 'Failed to update your identity, try again later or contact the server admin!' } })
				end
			end)
		end
	end)
end, function(source, args, user)
	TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'Insufficient permissions!' } })
end, {help = "Switch between character", params = {{name = "char", help = "the character id, ranges from 1-"..Config.MaxCharacters}}})

TriggerEvent('es:addGroupCommand', 'chardel', 'user', function(source, args, user)
	local charNumber = tonumber(args[1])

	if charNumber == nil or charNumber > Config.MaxCharacters or charNumber < 1 then
		TriggerClientEvent('chat:addMessage', source, { args = { '^[IDENTITY]', 'That\'s an invalid character!' } })
		return
	end

	getCharacters(source, function(data)
		if #data.characters < charNumber then
			TriggerClientEvent('chat:addMessage', source, { args = { '^1[IDENTITY]', 'You don\'t have a character in slot ' .. charNumber .. '!' } })
		else
			local data = {
				identifier	= data.identifier,
				character = data.characters[charNumber]
			}

			deleteIdentity(GetPlayerIdentifiers(source)[1], data, function(callback)
				if callback then
					TriggerClientEvent('chat:addMessage', source, { args = { '^1[IDENTITY]', 'You have deleted ^1' .. data.character.firstname .. ' ' .. data.character.lastname } })
				else
					TriggerClientEvent('chat:addMessage', source, { args = { '^1[IDENTITY]', 'Failed to delete the character, try again later or contact the server admin!' } })
				end
			end)
		end
	end)
end, function(source, args, user)
	TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'Insufficient permissions!' } })
end, {help = "Delete a registered character", params = {{name = "char", help = "the character id, ranges from 1-"..Config.MaxCharacters}}})
<<<<<<< HEAD

=======
>>>>>>> 88818bd3d832a52544322e4f55fd3f01801fa9ea
