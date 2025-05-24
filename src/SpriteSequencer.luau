--!strict
--!native

local RunService = game:GetService('RunService')

type SpriteSheet = {
	display: (cell: number) -> (),
	--...
	instance: ImageLabel
}

type Sequence = {
	looping: boolean,
	reverses: boolean,
	cells: {number},
	framerate: number,

	play: (fps: number, looping: boolean?, reverses: boolean?) -> (),
	stop: () -> (),
	isPlaying: () -> boolean,
	_nextFrame: (now: number) -> (),
	_previousFrame: (now: number) -> (),
	_playingInReverse: boolean,
	
	_didLoopBindable: BindableEvent,
	didLoop: RBXScriptSignal,
}

local MAX_FPS = 60

local activeSequences: {[ImageLabel]: Sequence} = {}

do
	local scheduler = if RunService:IsClient() then 'RenderStepped' else 'Heartbeat'
	
	local t = tick()
	local frames = 0
	RunService[scheduler]:Connect(function()
		--calculate FPS
		frames += 1
		local now = tick()
		local elapsed = now-t
		
		if elapsed >= 1 then
			MAX_FPS = math.floor(frames / elapsed)
			t = now	
			frames = 0
		end
		
		--execute sequences
		for instance, sequence in activeSequences do
			if not instance or not instance.Parent then
				sequence.stop()
				continue
			end
			
			if sequence._playingInReverse then
				sequence._previousFrame(now)
			else
				sequence._nextFrame(now)
			end
		end
	end)
end


local constructor = {}

function constructor.new(spritesheet: SpriteSheet, cells: {number})
	local sequence = {
		looping = false,
		reverses = false,
		cells = cells,
		framerate = MAX_FPS,
		_playingInReverse = false,
		_didLoopBindable = Instance.new("BindableEvent")
	} :: Sequence

	sequence.didLoop = sequence._didLoopBindable.Event

	function sequence.play(fps: number, looping: boolean?, reverses: boolean?)
		reverses = reverses or false
		looping = looping or false
		fps = fps or MAX_FPS
		sequence.reverses = reverses :: boolean
		sequence.looping = looping :: boolean
		sequence.framerate = fps
		
		local hasActiveSequence = activeSequences[spritesheet.instance]
		
		if hasActiveSequence then
			if hasActiveSequence == sequence then return end
			--overwrite the other sequence thats playing
			hasActiveSequence.stop()
		end
		
		activeSequences[spritesheet.instance] = sequence
		
	end
	
	function sequence.isPlaying()
		return activeSequences[spritesheet.instance] == sequence
	end
	
	local current_sequence_index = 0
	local last_execution = tick()
	function sequence._nextFrame(now: number)
		if now - last_execution <  1/sequence.framerate then return end
		last_execution = now
		
		current_sequence_index += 1
		spritesheet.display(cells[current_sequence_index])
		
		if current_sequence_index >= #cells then
			if sequence.looping then
				if sequence.reverses then
					sequence._playingInReverse = true
				else
					current_sequence_index = 0
					sequence._didLoopBindable:Fire()
				end
			else
				if sequence.reverses then
					sequence._playingInReverse = true
				else
					sequence.stop()
				end
			end
		end
	end
	
	function sequence._previousFrame(now: number)
		if now - last_execution <  1/sequence.framerate then return end
		last_execution = now
		
		current_sequence_index -= 1
		spritesheet.display(cells[current_sequence_index])
		
		if current_sequence_index <= 1 then
			if sequence.looping then
				sequence._playingInReverse = false
				sequence._didLoopBindable:Fire()
			else
				sequence._playingInReverse = false
				sequence.stop()
			end
		end
	end
	
	function sequence.stop()
		current_sequence_index = 0
		sequence._playingInReverse = false
		
		local activesequence = activeSequences[spritesheet.instance]
		if not activesequence then return end
		if activesequence ~= sequence then return end
		
		activeSequences[spritesheet.instance] = nil
	end
	
	return sequence
end

function constructor.fromRange(spritesheet: SpriteSheet, from: number, to: number)
	assert(to-from > 0, '.fromRange only accepts positive ranges')
	
	local cells = {}
	for i = from, to do cells[#cells+1] = i end
	
	return constructor.new(spritesheet, cells)
end

return constructor
