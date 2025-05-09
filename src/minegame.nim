import raylib
import os, strutils, math, random, sequtils

const
  SCREEN_WIDTH = 800
  SCREEN_HEIGHT = 600

  MAX_VELOCITY = 400.0
  ACCELERATION = 400.0
  DECELERATION = 100.0
  STOP_THRESHOLD = 10.0

type
  Scene = enum
    Menu, Gameplay

  Entity = ref object of RootObj
    tag: int
    pos: Vector2
    size: Vector2

  Player = ref object of Entity
    vel: Vector2
    score: int

proc `==`(e1, e2: Entity): bool =
  e1.tag == e2.tag and
  e1.pos.x == e2.pos.x and e1.pos.y == e2.pos.y and
  e1.size.x == e2.size.x and e1.size.y == e2.size.y

proc initEntity(tag: int, pos: Vector2, size: Vector2): Entity =
  result = new(Entity)
  result.tag = tag
  result.pos = pos
  result.size = size

proc initPlayer(tag: int, pos: Vector2, size: Vector2): Player =
  result = new(Player)
  result.tag = tag
  result.pos = pos
  result.size = size
  result.vel = Vector2(x: 0, y: 0)
  result.score = 0

proc readHighscore(filePath: string): int =
  var highscore = 0
  if fileExists(filePath):
    let content = readFile(filePath)
    highscore = parseInt(content.strip())
  return highscore

proc entitiesCollide(ent1: Entity, ent2: Entity): bool =
  let x_overlap = (ent1.pos.x < ent2.pos.x + ent2.size.x) and
                  (ent1.pos.x + ent1.size.x > ent2.pos.x)

  let y_overlap = (ent1.pos.y < ent2.pos.y + ent2.size.y) and
                  (ent1.pos.y + ent1.size.y > ent2.pos.y)

  return x_overlap and y_overlap

proc randEntity(tag_bottom_border: int, tag_top_border: int): Entity =
  let tag = rand(tag_bottom_border..tag_top_border)
  let pos_x = rand(0..(SCREEN_WIDTH - 50))
  let pos_y = rand(0..(SCREEN_HEIGHT - 50))
  result = Entity(
    tag: tag,
    pos: Vector2(x: pos_x.float, y: pos_y.float),
    size: Vector2(x: 50.0, y: 50.0)
  )

proc generateEntity(entities: var seq[Entity], player: var Player, other_entities: var seq[Entity]) =
  var generating = true
  while generating:
    var new_entity: Entity = randEntity(0, 1000)

    if entitiesCollide(player, new_entity): continue

    var collision_with_others = false

    for other_entity in other_entities:
      if entitiesCollide(new_entity, other_entity):
        collision_with_others = true
        break

    if not collision_with_others:
      entities.add(new_entity)
      generating = false
  
proc handleMovement(player: var Player, dt: float32) =
  if isKeyDown(D): player.vel.x += ACCELERATION * dt
  if isKeyDown(A): player.vel.x -= ACCELERATION * dt
  if isKeyDown(S): player.vel.y += ACCELERATION * dt
  if isKeyDown(W): player.vel.y -= ACCELERATION * dt

  # Clamp velocity
  if player.vel.x > MAX_VELOCITY: player.vel.x = MAX_VELOCITY
  if player.vel.x < -MAX_VELOCITY: player.vel.x = -MAX_VELOCITY
  if player.vel.y > MAX_VELOCITY: player.vel.y = MAX_VELOCITY
  if player.vel.y < -MAX_VELOCITY: player.vel.y = -MAX_VELOCITY

  # Update position
  player.pos.x += player.vel.x * dt
  player.pos.y += player.vel.y * dt

  # Horizontal boundary constraint
  if player.pos.x > float32(SCREEN_WIDTH) - player.size.x:
    player.pos.x = float32(SCREEN_WIDTH) - player.size.x
    player.vel.x = 0
  elif player.pos.x < 0.0:
    player.pos.x = 0.0
    player.vel.x = 0

  # Vertical boundary constraint
  if player.pos.y > float32(SCREEN_HEIGHT) - player.size.y:
    player.pos.y = float32(SCREEN_HEIGHT) - player.size.y
    player.vel.y = 0
  elif player.pos.y < 0.0:
    player.pos.y = 0.0
    player.vel.y = 0

  # Decelerate when no input is applied
  if not isKeyDown(D) and not isKeyDown(A):
    if abs(player.vel.x) < STOP_THRESHOLD:
      player.vel.x = 0.0 # Stop small velocities
    else:
      player.vel.x -= DECELERATION * dt * float32(sgn(player.vel.x))

  if not isKeyDown(S) and not isKeyDown(W):
    if abs(player.vel.y) < STOP_THRESHOLD:
      player.vel.y = 0.0 # Stop small velocities
    else:
      player.vel.y -= DECELERATION * dt * float32(sgn(player.vel.y))

proc main() =
  initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Mine Game")
  initAudioDevice()

  let window_icon = loadImage("assets/icon.png")
  setWindowIcon(window_icon)

  var highscore = readHighscore("highscore.txt")

  let title_image: Texture2D = loadTexture("assets/title.png")
  let coin_sfx: Sound = loadSound("assets/coin.wav")
  let mine_sfx: Sound = loadSound("assets/boom.wav")
  let tada_sfx: Sound = loadSound("assets/tada.wav")

  var playing = true
  var scene: Scene = Menu
  var round_timer = 0.0f

  var player: Player = initPlayer(
    0,
    Vector2(x: SCREEN_WIDTH / 2 - 25, y: SCREEN_HEIGHT / 2 - 25),
    Vector2(x: 50, y: 50)
  )

  var mines: seq[Entity]
  var coins: seq[Entity]

  playSound(tada_sfx)

  while not windowShouldClose():
    case scene:
      of Menu:
        if isKeyPressed(Enter):
          scene = GAMEPLAY
      of Gameplay:
        var dt = getFrameTime()
        round_timer += dt

        handleMovement(player, dt)

        if round_timer > 3:
          generateEntity(mines, player, coins)
          generateEntity(coins, player, mines)
          round_timer = 0

        for mine in mines:
          if entitiesCollide(player, mine):
            playSound(mine_sfx)
            playing = false
            break

        var coins_to_remove: seq[Entity] = @[]
        
        for coin in coins:
          if entitiesCollide(player, coin):
            playSound(coin_sfx)
            player.score += 1
            coins_to_remove.add(coin)

        for coin in coins_to_remove:
          coins = coins.filterIt(it != coin)

        if not playing:
          if player.score > highscore: highscore = player.score

          player = initPlayer(
            0,
            Vector2(x: SCREEN_WIDTH / 2 - 25, y: SCREEN_HEIGHT / 2 - 25),
            Vector2(x: 50, y: 50)
          )

          mines = @[]
          coins = @[]

          playing = true
          scene = Menu

    beginDrawing()
    clearBackground(RAYWHITE)
    
    case scene:
      of Menu:
        drawText(
          "Press enter to play",
          SCREEN_WIDTH - 214, SCREEN_HEIGHT - 30,
          20, RED
        )
        drawText(
          "Highscore: " & intToStr(highscore),
          20, SCREEN_HEIGHT - 30,
          20, RED
        )
        drawTexture(
          title_image,
          Vector2(x: SCREEN_WIDTH / 2 - 100, y: 200),
          WHITE
        )
        
      of Gameplay:
        drawRectangle(
          Vector2(x: player.pos.x, y: player.pos.y),
          Vector2(x: player.size.x, y: player.size.y),
          BLUE
        )

        for mine in mines:
          drawRectangle(
            Vector2(x: mine.pos.x, y: mine.pos.y),
            Vector2(x: mine.size.x, y: mine.size.y),
            RED
          )

        for coin in coins:
          drawRectangle(
            Vector2(x: coin.pos.x, y: coin.pos.y),
            Vector2(x: coin.size.x, y: coin.size.y),
            YELLOW
          )

        drawText(
          "Score " & intToStr(player.score),
          10, SCREEN_HEIGHT - 20,
          20, RED
        )
          
    drawFPS(10, 10)
    
    endDrawing()

  writeFile("highscore.txt", $highscore)

main()
