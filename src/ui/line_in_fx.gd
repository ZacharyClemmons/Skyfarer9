class_name LineInFx extends RichTextEffect
## [linein t0=MSEC]...[/linein]: a message line that slides in from the left and fades up,
## letter by letter, over about a third of a second. A RichTextLabel cannot animate one
## paragraph on its own, so the HUD wraps only the newest line in this tag and swaps the
## tag back out when it has finished (see Hud._settle_line); the effect never sits in the
## text for long, which keeps the label from redrawing every frame forever.

var bbcode := "linein"

func _process_custom_fx(c: CharFXTransform) -> bool:
	var t0 := float(c.env.get("t0", 0))
	var age := (float(Time.get_ticks_msec()) - t0) / 1000.0 - float(c.relative_index) * 0.006
	var k := clampf(age / 0.30, 0.0, 1.0)
	k = 1.0 - pow(1.0 - k, 3.0)
	c.color.a *= k
	c.offset.x -= (1.0 - k) * 16.0
	return true
