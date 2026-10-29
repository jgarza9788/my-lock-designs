# omarchy-lock-explorer: extra designs

Extra lock designs for the official
[omarchy-lock-explorer](https://github.com/SirJul1337/omarchy-lock-explorer)
plugin. This repo patches nothing in the plugin; it copies the designs into
`~/.config/omarchy/lock-designs`, where the explorer picks them up as
`my-<name>` under Custom.

```
./install.sh        # copy designs + shaders, restart the shell
./uninstall.sh      # remove them again, restart the shell
```

Both take `--no-restart`; `install.sh` also takes `--dry-run`. Re-run
`install.sh` after editing a design here.

Designs: Bubbles, Bullet, Circuits, ClockWall, Frost, Lightspeed, MazeClock,
PredatorClock, Proton, RingWordClock, SolClock, Terminator, Tracker, Waves,
WordClock, Xmb. Shaders live in `designs/shaders/` (`.frag` source plus the
compiled `.frag.qsb`).

Requires the plugin to be installed
(`omarchy plugin add https://github.com/SirJul1337/omarchy-lock-explorer.git --enable`).
