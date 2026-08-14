class DefaultKeyboardControlsScene
  def pbStartScene
    @sprites = {}
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    addBackgroundPlane(@sprites, "background", "helpbg2", @viewport)
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    overlay = @sprites["overlay"].bitmap
    baseColor = Color.new(230, 230, 230)
    shadowColor = Color.new(100, 100, 100)
    lineHeight = 28
    x = 14
    y = 8
    i = -1
    blindstep = $game_switches && $game_switches[:Blindstep]

    texts = []
    unless $joiplay
      texts.push ["C / Enter / Space:   Interact, Select", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
    else
      texts.push ["C / Enter:   Interact, Select", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
    end
    texts.push ["X / Escape:   Menu, Back, Skip Text", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
    texts.push ["A:   Mega, Z-Move, Sort, Misc.", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
    unless Rejuv
      texts.push ["S:   Use Item, Battle Field Notes", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
    else
      texts.push ["S:   Use Item", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
    end
    if Reborn
      if blindstep
        texts.push ["D:   Coordinates, Battle PULSE Notes", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
      else
        texts.push ["D:   Quick Save, Battle PULSE Notes", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
      end
    else
      texts.push ["D:   Quick Save", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
    end
    unless $joiplay
      texts.push ["Q / PgUp:   Previous Page, Self Inspect", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
      texts.push ["W / PgDn:   Next Page, Foe Inspect", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
      texts.push ["Ctrl + Q / W:   Skip 10 pages up or down", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
      texts.push ["Home / End:   Jump to the first or last item", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
      if blindstep
        texts.push ["Tab / M:   Toggle Turbo Mode", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
      else
        texts.push ["Tab / Alt / M:   Toggle Turbo Mode", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
      end
      texts.push ["Shift (hold) / Z:   Run", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
      texts.push ["F1:   Configure controls", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
      texts.push ["F7:   Mute, Unmute", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
    else
      texts.push ["Q:   Previous Page, Self Inspect", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
      texts.push ["W:   Next Page, Foe Inspect", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
      texts.push ["T:   Toggle Turbo Mode", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
      texts.push ["Z:   Toggle Run", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
      texts.push ["M:   Mute, Unmute", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
    end
    i -= 2
    x += 270
    if Reborn
      i -= 1
      texts.push ["Z (hold):   Smart Travel", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
    end
    if blindstep
      texts.push ["D (hold):   Quick Save", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
    else
      texts.push ["D (hold):   Coordinates", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
    end
    texts.push ["F12:   Soft Reset", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]

    @texts = texts
    @index = 0
    tts(texts[0][0])
    overlay.font.name = "PokemonEmerald"
    overlay.font.size = 36
    pbDrawTextPositions(overlay, texts)
    pbDeactivateWindows(@sprites)
    pbFadeInAndShow(@sprites) { pbUpdateSpriteHash(@sprites) }
  end

  def pbActivate
    pbActivateWindow(@sprites, nil) {
      loop do
        Graphics.update
        Input.update
        if Input.trigger?(Input::UP)
          @index -= 1
          if @index <= 0
            @index = @texts.length - 1
          end
          tts(@texts[@index][0])
        end
        if Input.trigger?(Input::DOWN)
          @index += 1
          if @index >= @texts.length
            @index = 0
          end
          tts(@texts[@index][0])
        end
        if Input.trigger?(Input::B) || Input.trigger?(Input::C)
          break
        end
      end
    }
  end

  def pbEndScene
    pbFadeOutAndHide(@sprites)
    pbDisposeSpriteHash(@sprites)
    pbRefreshSceneMap
    @viewport.dispose
  end

  def pbRender
    pbStartScene
    pbActivate
    pbEndScene
  end
end

class DefaultGamepadControlsScene
  def pbStartScene
    @sprites = {}
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    addBackgroundPlane(@sprites, "background", "helpbg2", @viewport)
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    overlay = @sprites["overlay"].bitmap
    baseColor = Color.new(230, 230, 230)
    shadowColor = Color.new(100, 100, 100)
    lineHeight = 28
    x = 14
    y = 8
    i = -1
    blindstep = $game_switches && $game_switches[:Blindstep]

    texts = []
    texts.push ["Cross / A:   Interact, Select", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
    texts.push ["Circle / B:   Menu, Back, Skip Text", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
    unless Rejuv
      texts.push ["Square / X:   Use Item, Battle Field Notes", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
    else
      texts.push ["Square / X:   Use Item", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
    end
    texts.push ["Triangle / Y:   Mega, Z-Move, Sort, Misc.", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
    texts.push ["L1:   Previous Page, Self Inspect", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
    texts.push ["R1:   Next Page, Foe Inspect", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
    texts.push ["R2 + L1 / R1:   Skip 10 pages up or down", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
    unless $joiplay
      texts.push ["L2 (hold) / Back:   Turbo Mode", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
      texts.push ["R2 (hold) / Start:   Run", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
      texts.push ["Start (hold):   Smart Travel", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor] if Reborn
    else
      texts.push ["L2:   Toggle Turbo Mode", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
      texts.push ["R2:   Toggle Run", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
      texts.push ["R2 (hold):   Smart Travel", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor] if Reborn
    end
    unless $joiplay
      texts.push ["LS:   Mute, Unmute", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
    end
    if Reborn
      if blindstep
        texts.push ["RS:   Coordinates, Battle PULSE Notes", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
      else
        texts.push ["RS:   Quick Save, Battle PULSE Notes", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
      end
    else
      texts.push ["RS:   Quick Save", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
    end
    unless $joiplay
      texts.push ["Guide:   Soft Reset", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
      x += 250
      i -= 1
    end
    if blindstep
      texts.push ["RS (hold):   Quick Save", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
    else
      texts.push ["RS (hold):   Coordinates", x, y + lineHeight * (i += 1), 0, baseColor, shadowColor]
    end

    @texts = texts
    @index = 0
    tts(texts[0][0])
    overlay.font.name = "PokemonEmerald"
    overlay.font.size = 36
    pbDrawTextPositions(overlay, texts)
    pbDeactivateWindows(@sprites)
    pbFadeInAndShow(@sprites) { pbUpdateSpriteHash(@sprites) }
  end

  def pbActivate
    pbActivateWindow(@sprites, nil) {
      loop do
        Graphics.update
        Input.update
        if Input.trigger?(Input::UP)
          @index -= 1
          if @index <= 0
            @index = @texts.length - 1
          end
          tts(@texts[@index][0])
        end
        if Input.trigger?(Input::DOWN)
          @index += 1
          if @index >= @texts.length
            @index = 0
          end
          tts(@texts[@index][0])
        end
        if Input.trigger?(Input::B) || Input.trigger?(Input::C)
          break
        end
      end
    }
  end

  def pbEndScene
    pbFadeOutAndHide(@sprites)
    pbDisposeSpriteHash(@sprites)
    pbRefreshSceneMap
    @viewport.dispose
  end

  def pbRender
    pbStartScene
    pbActivate
    pbEndScene
  end
end

def controlsDialogue
  commands = []
  commands.push(_INTL("Configure (F1)")) unless $joiplay
  commands.push(_INTL($joiplay ? "Basic Controls" : "Keyboard Defaults"))
  commands.push(_INTL($joiplay ? "Gamepad Controls" : "Gamepad Defaults"))
  command = Kernel.pbMessage(_INTL("What controls do you want to see?"), commands, -1)

  return if command == -1

  if !$joiplay && command == 0
    System.show_settings
    return
  end

  command += 1 if $joiplay

  if command == 1
    scene = DefaultKeyboardControlsScene.new
    pbFadeOutIn(99999) { scene.pbRender }
  elsif command == 2
    scene = DefaultGamepadControlsScene.new
    pbFadeOutIn(99999) { scene.pbRender }
    Kernel.pbMessage(_INTL("Note that some gamepad buttons may not be recognized by JoiPlay.")) if $joiplay
  end
end
