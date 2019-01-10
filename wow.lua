loadlib("luadg", "luaopen_luadg")();

video_mode=
{
	xres=640,
	yres=480,
	bpp=32,
	options=0,
	loglevel=0
};

function getImageName(name, ext)
	return lrun.home.."/"..name.."."..(ext or "png");
end

function newSprite(video, x, y, w, h, src)
	local image=video:create_image(x, y, w, h);
	image:set_visible(1);
	image:set_src(src);
	image:set_back_color(dg.color(0, 0, 255, 0));
	image:set_border_color(dg.color(255, 255, 255, 0));
	image:set_transparent(1);
	return image;
end

function newLabel(video, x, y, w, h, str)
	local label=video:create_label(x, y, w, h);
	label:set_visible(1);
	label:set_font("Arial", 24);
	label:set_text(str);
	label:set_text_color(dg.color(0, 255, 255, 0));
	label:set_shadow_color(dg.color(1, 0, 0, 0));
	label:set_justify(dg.JUSTIFY_CENTER_X);
	return label;
end

Sprite={
	sprites={};
};

function Sprite:new(video, x, y, dx, dy, w, h, img_name)
	local t={x=x, y=y, dx=dx, dy=dy, w=w, h=h};
	t.sprite=newSprite(video, x, y, w, h, getImageName(img_name, "png"));
	return t;
end

function Sprite:update()
	table.foreach(self.sprites, function(_, sprite)
		sprite:render();
	end);
end

Fire={
	max_friend=1,
	max_enemy=10,
	fires={}
};

function Fire:move()
	self.y=self.y+self.dy;
	if self.y<=0 or self.y>=video_mode.yres then
		self:kill();
	end
	self.sprite:set_y(self.y);
end

function Fire:kill()
	Fire.fires[self.index]=nil;
end

function Fire:new(video, x, y, dy, img_name, friendly)
	local i;
	local fires_start = friendly and 1 or (Fire.max_friend+1);
	local fires_end   = friendly and Fire.max_friend or (Fire.max_friend+Fire.max_enemy);
	for i=fires_start,fires_end do
		if not Fire.fires[i] then
			local t=Sprite:new(video, x, y, 0, dy, 32, 32, img_name);
			t.move=Fire.move;
			t.kill=Fire.kill;
			t.friendly=friendly;
			Fire.fires[i]=t;
			t.index=i;
			break;
		end
	end
end

Enemy={
	hits=0
};

function Enemy:move(video)
	self.x=self.x+self.dx;
	if self.x==0 or self.x==video_mode.xres-self.w then
		self.dx=-self.dx;
	end
	self.sprite:set_x(self.x);
	local maxrand=20-Enemy.hits;
	if maxrand<5 then
		maxrand=5;
	end
	local r=math.random(maxrand);
	if r == 5 then
		Fire:new(video, self.x, self.y+1, 3, "fire_down", false);
	end
end

function Enemy:new(video)
	local t=Sprite:new(video, 0, 0, 1, 0, 78, 57, "enemy");
	table.insert(Sprite.sprites, t.sprite);
	t.move=Enemy.move;
	t.friendly=false;
	return t;
end

Friend={
	step=10,
	hits=0
};

function Friend:left()
	if self.x-Friend.step>0 then
		self.x=self.x-Friend.step;
	else
		self.x=0;
	end
	self.sprite:set_x(self.x);
end

function Friend:right()
	if self.x+Friend.step<video_mode.xres-self.w then
		self.x=self.x+Friend.step;
	else
		self.x=video_mode.xres-self.w;
	end
	self.sprite:set_x(self.x);
end

function Friend:moveTo(x, y)
	if x<video_mode.xres-self.w then
		self.x=x;
		self.sprite:set_x(self.x);
	end
end

function Friend:fire(video)
	Fire:new(video, self.x, self.y, -1, "fire_up", true);
end

function Friend:new(video)
	local t=Sprite:new(video, 0, video_mode.yres-57, 0, 0, 78, 57, "friend");
	table.insert(Sprite.sprites, t.sprite);
	t.left=Friend.left;
	t.right=Friend.right;
	t.moveTo=Friend.moveTo;
	t.fire=Friend.fire;
	t.friendly=true;
	return t;
end

function CheckIntersection(sprite1, sprite2)
	if sprite1.x>=sprite2.x and sprite1.x+sprite1.w<=sprite2.x+sprite2.w then
		if sprite1.y>=sprite2.y and sprite1.y+sprite1.h<=sprite2.y+sprite2.h then
			return true;
		end
		
	end
end

function CheckCollisions(sprites)
	local i;
	local isHit;
	for i=1,Fire.max_friend+Fire.max_enemy do
		local fire=Fire.fires[i];
		if fire then
			table.foreachi(sprites, function (_, sprite)
				if CheckIntersection(fire, sprite) then
					if fire.friendly and not sprite.friendly then
						fire:kill();
						Friend.hits=Friend.hits + 1;
						isHit=true;
					elseif not fire.friendly and sprite.friendly then
						fire:kill();
						Enemy.hits=Enemy.hits + 1;
					end
				end
			end);
		end
	end
	return isHit;
end

function main()
	local timeTotal=0;
	local framesCount=0;
	local fps=0;
	local video  = dg.new(video_mode.xres, video_mode.yres, video_mode.bpp, video_mode.options, video_mode.loglevel);
	local enemies = { Enemy:new(video) };
	local friend = Friend:new(video);
	local statFriend = newLabel(video, 0, 40, 150, 50, "Friend: 0");
	local statEnemy  = newLabel(video, video_mode.xres-150, 40, 150, 50, "Enemy: 0");
	local labelFPS  = newLabel(video, video_mode.xres-150, 100, 150, 50, "0 FPS");
	local background = video:create_image(0, 0, video_mode.xres, video_mode.yres);
	background:set_visible(1);
	background:set_src(getImageName("background", "jpg"));

	video:init_events{
		keyboard=function (_, code, modifiers, isPressed)
			if code == 27 then
				video:destroy_events();
			elseif code == 37 then -- left
				friend:left();
			elseif code == 39 then -- right
				friend:right();
			elseif code == 32 then -- fire
				friend:fire(video);
			end
		end,
		mouse=function(_, x, y, buttons)
			friend:moveTo(x, y);
			if buttons == 1 then
				friend:fire(video);
			end
		end,
		idle=function()
			local time_start=os.clock();
			local i;
			--video:clear(0);
			background:render();
			table.foreachi(enemies, function(_, enemy)
				enemy:move(video);
			end);
			for i=1,Fire.max_friend+Fire.max_enemy do
				if Fire.fires[i] then
					Fire.fires[i].sprite:render();
					Fire.fires[i]:move();
				end
			end
			if CheckCollisions(enemies) then
				--table.insert(enemies, Enemy:new(video));
			end
			CheckCollisions({friend});
			Sprite:update();
			statFriend:set_text("Friend: "..Friend.hits);
			statEnemy:set_text("Enemy: "..Enemy.hits);
			statFriend:render();
			statEnemy:render();

			--if Enemy.hits>1 then
			--	if Fire.max_friend ~= Enemy.hits then
			--		Fire.fires={};
			--		Fire.max_friend=Enemy.hits;
			--	end
			--end

			timeTotal=timeTotal+(os.clock()-time_start);
			framesCount=framesCount+1;
			if timeTotal>1 then
				timeTotal=0;
				fps=framesCount;
				framesCount=0;
			end
			if fps>0 then
				labelFPS:set_text(string.format("%d fps", fps));
				labelFPS:render();
			end
			video:flip();
		end
	};
end

main();
