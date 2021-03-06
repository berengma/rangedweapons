-- Weapons Only allowed in specified area
local xmin = 1110
local xmax = 2837
local zmin = -4919
local zmax = -3504
local check = true        -- if set to false you can use weapons everywhere
local trigger = {}




-- This functions checks if weapon is allowed at present position
-- returns true if so

local function wcheck_area(user)
       local rvar = true
       local uname = user:get_player_name()
       local wpos = user:getpos()
       local wprivs = minetest.get_player_privs(uname)
       
	    
	      if ((wpos.x > xmin) and (wpos.x < xmax) and (wpos.z > zmin) and (wpos.z < zmax)) or (not check) or wprivs.server then
		return rvar

	      else
		
		rvar = false
		minetest.chat_send_player(uname,"Using weapons in this area is not allowed")
		return rvar
	      end
       
end


-- This functions calculates the way of the bullet.
--
-- self and dtime you get from on_step call
-- checktime defines interval of position checks
-- damage = amount of damage done by the weapon
-- radius = in which radius from bullet is checked for a hit. in nodes, usually 1
-- entity_name = name of the bullet-entity
-- sound_name = sound played when hit
-- dragon_kill = server specific for jungle server. true can penetrate water_source

local function weapon_onstep(self, dtime, checktime, damage, radius, entity_name, sound_name, dragon_kill)
	self.timer = self.timer + dtime
	local pos = self.object:getpos()
	local node = minetest.get_node(pos)

	if self.timer > 0.05 then
		local objs = minetest.get_objects_inside_radius(pos, radius)
		local node =  minetest.get_node(pos)
		if node.name ~= "air" and (node.name ~= "default:water_source" or not dragon_kill) then    --only weapon with dragon_kill flag can penetrate water
		          if node.name == "default:apple" then minetest.remove_node(pos) end -- LOL 
			  self.object:remove()
			  self.timer = 0
		else
			
		      for k, obj in pairs(objs) do
			      if obj:get_luaentity() ~= nil then
				      if obj:get_luaentity().name ~= entity_name and obj:get_luaentity().name ~= "__builtin:item" then
					if obj:get_luaentity().name == "dmobs:dragon" and not dragon_kill then
					      self.object:remove()
					else
					      
					      obj:punch(self.object, 1.0, {
					      full_punch_interval = 1.0,
					      damage_groups= {fleshy = damage},
					      }, nil)
					      minetest.sound_play(sound_name, {pos = self.lastpos, gain = 0.8})
					      self.object:remove()
					end
				     
				      end
			      end
			      if obj:is_player() then
					      obj:punch(self.object, 1.0, {
					      full_punch_interval = 1.0,
					      damage_groups= {fleshy = damage},
					      }, nil)
					      minetest.sound_play(sound_name, {pos = self.lastpos, gain = 0.8})
					      self.object:remove()		
			      end
		      end
		      self.timer = 0
		end
	end

	
	
	self.lastpos= pos
end


-- this function is called when you trigger the button(shoot the weapon)
-- itemstack, user, pointed thing you get from on_use function. pass through
-- cooldown = how many seconds to wait until next use is possible
-- entity_name = name of the bullet-entity
-- velocity = velocity of the bullet
-- grav = gravity, bullets will not go straight
-- ammo = specify ammonition here. if nil the thing you hold will be used
-- nocheck = if set to true weapon will not be checked for area, even if area-check is turned on

local function weapon_shoot(itemstack, user, pointed_thing, cooldown, entity_name, velocity, grav, ammo, nocheck)	
    local name = user:get_player_name()
    
	if (wcheck_area(user) or nocheck) and not trigger[name] then
		
	     
			
		if pointed_thing.type ~= "nothing" then
			local pointed = minetest.get_pointed_thing_position(pointed_thing)
			if vector.distance(user:getpos(), pointed) < 8 then
				return itemstack
			end
		end
		
		local pos = user:getpos()
		local dir = user:get_look_dir()
		local yaw = user:get_look_yaw()
		if pos and dir then
			pos.y = pos.y + 1.7
			local obj = minetest.add_entity(pos, entity_name)
			if not minetest.setting_getbool("creative_mode") then 
				if not ammo then 
					itemstack:take_item() 
				else
					local inv = user:get_inventory()
					inv:remove_item("main", ammo)
				end
			end
			if obj then
				obj:setvelocity({x=dir.x * velocity, y=dir.y * velocity, z=dir.z * velocity})
				if not grav then
				  obj:setacceleration({x=dir.x * -3, y=-10, z=dir.z * -3})
				  obj:setyaw(yaw + math.pi)
				else
				  obj:setacceleration({x=dir.x * 0, y= 0, z=dir.z * 0})
				end
				local ent = obj:get_luaentity()
				if ent then
					ent.player = ent.player or user
				end
			end
		end
		trigger[name] = true
		minetest.after(cooldown,function()
		    trigger[name] = nil
		end)
		return itemstack
        end
end
	  


minetest.register_craftitem("rangedweapons:javelint", {
	wield_scale = {x=2,y=2,z=1.0},
	inventory_image = "ranged_javelin.png",
})

minetest.register_craftitem("rangedweapons:javelin", {
	description = "javelin(ranged damage 6) reload in 1 sec",
	wield_scale = {x=2,y=2,z=1.0},
	range = 5,
	inventory_image = "ranged_javelin_inv.png",
	stack_max= 200,
	on_use = function(itemstack, user, pointed_thing)
	    weapon_shoot(itemstack, user, pointed_thing, 1, "rangedweapons:javelin_entity", 30)
	    return itemstack
	end
})

minetest.register_craft({
	output = 'rangedweapons:javelin 1',
	recipe = {
		{'default:steel_ingot', 'default:steel_ingot', ''},
		{'default:steel_ingot', 'default:stick', ''},
		{'', '', 'default:stick'},
	}
})

local rangedweapons_javelin_ENTITY = {
	physical = false,
	timer = 0,
	visual = "wielditem",
	visual_size = {x=0.5, y=0.5},
	textures = {"rangedweapons:javelint"},
	lastpos= {},
	collisionbox = {0, 0, 0, 0, 0, 0},
}

rangedweapons_javelin_ENTITY.on_step = function(self, dtime)
	weapon_onstep(self,dtime,0.5,4,1,"rangedweapons:javelin_entity","rangedweapons_arrow")
end

minetest.register_entity("rangedweapons:javelin_entity", rangedweapons_javelin_ENTITY)


minetest.register_craftitem("rangedweapons:wooden_shuriken", {
	description = "wooden shuriken(ranged damage 4) reload in 1 sec",
	range = 0,
	stack_max= 200,
	inventory_image = "rangedweapons_wooden_shuriken.png",
	on_use = function(itemstack, user, pointed_thing)
	      weapon_shoot(itemstack, user, pointed_thing, 1, "rangedweapons:woodsr", 35)
	      return itemstack
	end
})

local RANGEDWEAPONS_WOODSR = {
	physical = false,
	timer = 0,
	visual = "cube",
	visual_size = {x=0.5, y=0.0,},
	textures = {'rangedweapons_wooden_shuriken.png','rangedweapons_wooden_shuriken.png','rangedweapons_wooden_shuriken.png','rangedweapons_wooden_shuriken.png','rangedweapons_wooden_shuriken.png','rangedweapons_wooden_shuriken.png'},
	lastpos= {},
	collisionbox = {0, 0, 0, 0, 0, 0},
}
RANGEDWEAPONS_WOODSR.on_step = function(self, dtime)
	weapon_onstep(self,dtime,0.5,4,1,"rangedweapons:woodsr","default_dig_cracky")	
end

minetest.register_entity("rangedweapons:woodsr", RANGEDWEAPONS_WOODSR)

minetest.register_craft({
	output = 'rangedweapons:wooden_shuriken 32',
	recipe = {
		{'', 'group:wood', ''},
		{'group:wood', '', 'group:wood'},
		{'', 'group:wood', ''},
	}
})




minetest.register_craftitem("rangedweapons:stone_shuriken", {
	description = "stone shuriken(ranged damage 4) reload in 1 sec",
	range = 0,
	stack_max= 200,
	inventory_image = "rangedweapons_stone_shuriken.png",
	on_use = function(itemstack, user, pointed_thing)
		weapon_shoot(itemstack, user, pointed_thing, 1, "rangedweapons:stonesr", 20)
		return itemstack
	end
})

local RANGEDWEAPONS_STONESR = {
	physical = false,
	timer = 0,
	visual = "cube",
	visual_size = {x=0.5, y=0.0,},
	textures = {'rangedweapons_stone_shuriken.png','rangedweapons_stone_shuriken.png','rangedweapons_stone_shuriken.png','rangedweapons_stone_shuriken.png','rangedweapons_stone_shuriken.png','rangedweapons_stone_shuriken.png'},
	lastpos= {},
	collisionbox = {0, 0, 0, 0, 0, 0},
}

RANGEDWEAPONS_STONESR.on_step = function(self, dtime)
	weapon_onstep(self,dtime,0.5,4,1,"rangedweapons:stonesr","default_dig_cracky")
end

minetest.register_entity("rangedweapons:stonesr", RANGEDWEAPONS_STONESR)

minetest.register_craft({
	output = 'rangedweapons:stone_shuriken 32',
	recipe = {
		{'', 'default:cobble', ''},
		{'default:cobble', '', 'default:cobble'},
		{'', 'default:cobble', ''},
	}
})


minetest.register_craftitem("rangedweapons:steel_shuriken", {
	description = "steel shuriken(ranged damage 6) reload in 1 sec",
	range = 0,
	stack_max= 200,
	inventory_image = "rangedweapons_steel_shuriken.png",
	on_use = function(itemstack, user, pointed_thing)
	      weapon_shoot(itemstack, user, pointed_thing, 1, "rangedweapons:steelsr", 45)
	      return itemstack
	end
})

local RANGEDWEAPONS_STEELSR = {
	physical = false,
	timer = 0,
	visual = "cube",
	visual_size = {x=0.5, y=0.0,},
	textures = {'rangedweapons_steel_shuriken.png','rangedweapons_steel_shuriken.png','rangedweapons_steel_shuriken.png','rangedweapons_steel_shuriken.png','rangedweapons_steel_shuriken.png','rangedweapons_steel_shuriken.png'},
	lastpos= {},
	collisionbox = {0, 0, 0, 0, 0, 0},
}
RANGEDWEAPONS_STEELSR.on_step = function(self, dtime)
	weapon_onstep(self,dtime,0.5,6,1,"rangedweapons:steelsr","default_dig_cracky")
end

minetest.register_entity("rangedweapons:steelsr", RANGEDWEAPONS_STEELSR)

minetest.register_craft({
	output = 'rangedweapons:steel_shuriken 32',
	recipe = {
		{'', 'default:steel_ingot', ''},
		{'default:steel_ingot', '', 'default:steel_ingot'},
		{'', 'default:steel_ingot', ''},
	}
})


minetest.register_craftitem("rangedweapons:bronze_shuriken", {
	description = "bronze shuriken(ranged damage 8) reload in 0.5 sec",
	range = 0,
	stack_max= 200,
	inventory_image = "rangedweapons_bronze_shuriken.png",
	on_use = function(itemstack, user, pointed_thing)
	      weapon_shoot(itemstack, user, pointed_thing, 0.5,"rangedweapons:bronzesr", 50)
	      return itemstack
	end
})

local RANGEDWEAPONS_BRONZESR = {
	physical = false,
	timer = 0,
	visual = "cube",
	visual_size = {x=0.5, y=0.0,},
	textures = {'rangedweapons_bronze_shuriken.png','rangedweapons_bronze_shuriken.png','rangedweapons_bronze_shuriken.png','rangedweapons_bronze_shuriken.png','rangedweapons_bronze_shuriken.png','rangedweapons_bronze_shuriken.png'},
	lastpos= {},
	collisionbox = {0, 0, 0, 0, 0, 0},
}
RANGEDWEAPONS_BRONZESR.on_step = function(self, dtime)
	weapon_onstep(self,dtime,0.5,8,1,"rangedweapons:bronzesr","default_dig_cracky")
end

minetest.register_entity("rangedweapons:bronzesr", RANGEDWEAPONS_BRONZESR)

minetest.register_craft({
	output = 'rangedweapons:bronze_shuriken 32',
	recipe = {
		{'', 'default:bronze_ingot', ''},
		{'default:bronze_ingot', '', 'default:bronze_ingot'},
		{'', 'default:bronze_ingot', ''},
	}
})

minetest.register_craftitem("rangedweapons:gold_shuriken", {
	description = "golden shuriken(ranged damage 10) reload in 0.5 sec",
	range = 0,
	stack_max= 200,
	inventory_image = "rangedweapons_golden_shuriken.png",
	on_use = function(itemstack, user, pointed_thing)
	      weapon_shoot(itemstack, user, pointed_thing, 0.5,"rangedweapons:goldsr", 35)
	      return itemstack
	end
})

local RANGEDWEAPONS_GOLDSR = {
	physical = false,
	timer = 0,
	visual = "cube",
	visual_size = {x=0.5, y=0.0,},
	textures = {'rangedweapons_golden_shuriken.png','rangedweapons_golden_shuriken.png','rangedweapons_golden_shuriken.png','rangedweapons_golden_shuriken.png','rangedweapons_golden_shuriken.png','rangedweapons_golden_shuriken.png'},
	lastpos= {},
	collisionbox = {0, 0, 0, 0, 0, 0},
}
RANGEDWEAPONS_GOLDSR.on_step = function(self, dtime)
	weapon_onstep(self,dtime,0.5,10,1,"rangedweapons:goldsr","default_dig_cracky")
end

minetest.register_entity("rangedweapons:goldsr", RANGEDWEAPONS_GOLDSR)

minetest.register_craft({
	output = 'rangedweapons:gold_shuriken 32',
	recipe = {
		{'', 'default:gold_ingot', ''},
		{'default:gold_ingot', '', 'default:gold_ingot'},
		{'', 'default:gold_ingot', ''},
	}
})

minetest.register_craftitem("rangedweapons:mese_shuriken", {
	description = "mese shuriken(ranged damage 10) reload in 0.5 sec",
	range = 0,
	stack_max= 200,
	inventory_image = "rangedweapons_mese_shuriken.png",
	on_use = function(itemstack, user, pointed_thing)
		weapon_shoot(itemstack, user, pointed_thing, 0.5,"rangedweapons:mesesr", 50)
		return itemstack
	end
})

local RANGEDWEAPONS_MESESR = {
	physical = false,
	timer = 0,
	visual = "cube",
	visual_size = {x=0.5, y=0.0,},
	textures = {'rangedweapons_mese_shuriken.png','rangedweapons_mese_shuriken.png','rangedweapons_mese_shuriken.png','rangedweapons_mese_shuriken.png','rangedweapons_mese_shuriken.png','rangedweapons_mese_shuriken.png'},
	lastpos= {},
	collisionbox = {0, 0, 0, 0, 0, 0},
}

RANGEDWEAPONS_MESESR.on_step = function(self, dtime)
	weapon_onstep(self,dtime,0.5,10,1,"rangedweapons:mesesr","default_dig_cracky")
end

minetest.register_entity("rangedweapons:mesesr", RANGEDWEAPONS_MESESR)

minetest.register_craft({
	output = 'rangedweapons:mese_shuriken 32',
	recipe = {
		{'', 'default:mese_crystal', ''},
		{'default:mese_crystal', '', 'default:mese_crystal'},
		{'', 'default:mese_crystal', ''},
	}
})


minetest.register_craftitem("rangedweapons:diamond_shuriken", {
	description = "diamond shuriken(ranged damage 12) reload in 0.5 sec",
	range = 0,
	stack_max= 200,
	inventory_image = "rangedweapons_diamond_shuriken.png",
	on_use = function(itemstack, user, pointed_thing)
	      weapon_shoot(itemstack, user, pointed_thing, 0.5, "rangedweapons:diamondsr", 50)
	      return itemstack
	end
})

local RANGEDWEAPONS_DIAMONDSR = {
	physical = false,
	timer = 0,
	visual = "cube",
	visual_size = {x=0.5, y=0.0,},
	textures = {'rangedweapons_diamond_shuriken.png','rangedweapons_diamond_shuriken.png','rangedweapons_diamond_shuriken.png','rangedweapons_diamond_shuriken.png','rangedweapons_diamond_shuriken.png','rangedweapons_diamond_shuriken.png'},
	lastpos= {},
	collisionbox = {0, 0, 0, 0, 0, 0},
}
RANGEDWEAPONS_DIAMONDSR.on_step = function(self, dtime)
	weapon_onstep(self,dtime,0.5,12,1,"rangedweapons:diamondsr","default_dig_cracky")
end

minetest.register_entity("rangedweapons:diamondsr", RANGEDWEAPONS_DIAMONDSR)

minetest.register_craft({
	output = 'rangedweapons:diamond_shuriken 32',
	recipe = {
		{'', 'default:diamond', ''},
		{'default:diamond', '', 'default:diamond'},
		{'', 'default:diamond', ''},
	}
})

minetest.register_tool("rangedweapons:spas12", {
	description = "spas-12(ranged damage 35,bigger radius) penetrates water, reload in 2 sec",
	wield_scale = {x=1.5,y=1.5,z=1.5},
	inventory_image = "rangedweapons_spas12.png",
	on_use = function(itemstack, user, pointed_thing)
		local inv = user:get_inventory()
		if not trigger[user:get_player_name()] then
		    if not inv:contains_item("main", "rangedweapons:shell 1") then
			    minetest.sound_play("rangedweapons_empty", {object=user})
			    return itemstack
		    else
		      minetest.sound_play("rangedweapons_shotgun_shoot", {
		      pos = user:getpos(),
		      max_hear_distance = 100,
		      gain = 10.0,
		      })
		    end
		end
	      weapon_shoot(itemstack, user, pointed_thing, 2, "rangedweapons:spas12shot", 30, true, "rangedweapons:shell 1")
	end
})
minetest.register_craft({
	output = 'rangedweapons:spas12',
	recipe = {
		{'default:steel_ingot', 'default:steel_ingot', 'default:steel_ingot'},
		{'dye:black', 'default:diamond', 'default:steel_ingot'},
	}
})
local rangedweapons_spas12shot = {
	physical = false,
	timer = 0,
	visual = "sprite",
	visual_size = {x=0.25, y=0.25,},
	textures = {'shotshot.png'},
	lastpos= {},
	collisionbox = {0, 0, 0, 0, 0, 0},
}
rangedweapons_spas12shot.on_step = function(self, dtime)
	weapon_onstep(self,dtime,0.5,35,2,"rangedweapons:spas12shot","default_dig_cracky", true)
end

minetest.register_entity("rangedweapons:spas12shot", rangedweapons_spas12shot )

minetest.register_craftitem("rangedweapons:shell", {
	wield_scale = {x=0.2,y=0.2,z=0.75},
	stack_max= 500,
	description = "shotgun shell(ammunition for shotguns)",
	inventory_image = "rangedweapons_shell.png",
})


minetest.register_tool("rangedweapons:awp", {
	description = "awp(ranged damage 80) penetrates water, reload in 5 sec",
	wield_scale = {x=1.75,y=1.75,z=1.0},
	inventory_image = "rangedweapons_awp.png",
	on_use = function(itemstack, user, pointed_thing)
		local inv = user:get_inventory()
		if not trigger[user:get_player_name()] then
		    if not inv:contains_item("main", "rangedweapons:10mm 1") then
			    minetest.sound_play("rangedweapons_empty", {object=user})
			    return itemstack
		    else
		      minetest.sound_play("rangedweapons_rifle_shoot", {
		      pos = user:getpos(),
		      max_hear_distance = 100,
		      gain = 10.0,
		      })
		    end
		end
	      weapon_shoot(itemstack, user, pointed_thing, 5, "rangedweapons:awpshot", 40, true, "rangedweapons:10mm 1")
	end
})
minetest.register_craft({
	output = 'rangedweapons:awp',
	recipe = {
		{'default:diamond', 'default:steel_ingot', 'default:diamond'},
		{'default:steel_ingot', 'default:steel_ingot', 'default:steel_ingot'},
		{'dye:green', 'default:diamond', 'default:steel_ingot'},

	}
})

local rangedweapons_awpshot = {
	physical = false,
	timer = 0,
	visual = "sprite",
	visual_size = {x=0.25, y=0.25,},
	textures = {'shot.png'},
	lastpos= {},
	collisionbox = {0, 0, 0, 0, 0, 0},
}
rangedweapons_awpshot.on_step = function(self, dtime)
	weapon_onstep(self,dtime,0.5,80,2,"rangedweapons:awpshot","default_dig_cracky", true)
end

minetest.register_entity("rangedweapons:awpshot", rangedweapons_awpshot )



minetest.register_craftitem("rangedweapons:10mm", {
	stack_max= 500,
	description = "10mm bullet(ammunition for rifles)",
	wield_scale = {x=0.2,y=0.2,z=0.75},
	inventory_image = "rangedweapons_10mm.png",
})


-- special christmas edition by Gundul:


minetest.override_item("default:snow", {
	description = "Snowball(ranged damage 2) reload in 0.2 sec",
	range = 0,
	stack_max= 1024,
	on_use = function(itemstack, user, pointed_thing)
		weapon_shoot(itemstack, user, pointed_thing, 0.2, "rangedweapons:snowball", 30, false,false, true)
		return itemstack
	end
})

local RANGEDWEAPONS_SNOWBALL = {
	physical = false,
	timer = 0,
	visual = "sprite",
	visual_size = {x=0.15, y=0.15,},
	textures = {"default_snow.png"},
	lastpos= {},
	collisionbox = {0, 0, 0, 0, 0, 0},
}
RANGEDWEAPONS_SNOWBALL.on_step = function(self, dtime)
	weapon_onstep(self,dtime,0.5,2,1,"rangedweapons:snowball","default_dig_cracky")
end

minetest.register_entity("rangedweapons:snowball", RANGEDWEAPONS_SNOWBALL)




------------------
-- The recipes !--
------------------


if minetest.get_modpath("lavaex") then
  
    minetest.register_craft({
	output = 'rangedweapons:shell',
	recipe = {
		{'homedecor:plastic_sheeting', 'technic:brass_ingot', 'homedecor:plastic_sheeting'},
		{'homedecor:plastic_sheeting', 'lavaex:gunpowder', 'homedecor:plastic_sheeting'},
		{'homedecor:plastic_sheeting', 'lavaex:gunpowder', 'homedecor:plastic_sheeting'}
	}
    })
    
    minetest.register_craft({
	output = 'rangedweapons:10mm 4',
	recipe = {
		{            '',     'technic:mixed_metal_ingot',                         ''},
		{'technic:brass_ingot', 'lavaex:gunpowder', 'technic:brass_ingot'},
		{'technic:brass_ingot', 'lavaex:gunpowder', 'technic:brass_ingot'}
	}
    })
end
  
