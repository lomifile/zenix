"""theme.py — palettes and the per-surface files generated from them."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

from tests.support import FIXTURE_THEME, RepoCase, make_theme

from zenix import theme
from zenix.console import ZenixError
from zenix.repo import Repo

# The real checkout, for the invariant and round-trip tests. Those are the two
# guards with lasting value, and neither can be expressed against a fixture:
# one is about the themes that actually ship, the other about whether the
# generator reproduces the configs that are actually committed.
REAL = Path(__file__).resolve().parent.parent.parent
HAS_REAL = (REAL / "install.sh").is_file() and (REAL / "themes").is_dir()
real_only = unittest.skipUnless(HAS_REAL, "not run from inside a zenix checkout")


class Blend(unittest.TestCase):
    def test_zero_is_the_base_and_one_is_the_overlay(self):
        self.assertEqual(theme.blend("#000000", "#ffffff", 0.0), "#000000")
        self.assertEqual(theme.blend("#000000", "#ffffff", 1.0), "#ffffff")

    def test_half_is_the_midpoint(self):
        self.assertEqual(theme.blend("#000000", "#ffffff", 0.5), "#808080")

    def test_an_eight_digit_base_drops_its_alpha(self):
        # Theme files spell translucent roles #AARRGGBB, and blending is about
        # hue, so the alpha must not be mistaken for a colour channel.
        self.assertEqual(theme.blend("#ff000000", "#ffffff", 0.5), "#808080")

    def test_a_short_colour_is_refused_rather_than_guessed(self):
        with self.assertRaises(ZenixError):
            theme.blend("#fff", "#000000", 0.5)

    def test_a_ramp_ends_on_the_colour_it_was_given(self):
        out = theme.ramp("#000000", "#a6e3a1")
        self.assertEqual(out[-1], "#a6e3a1")
        self.assertEqual(len(out), 3)
        self.assertLess(int(out[0][1:3], 16), int(out[1][1:3], 16))


class ReplaceBlock(unittest.TestCase):
    def text(self, body="old = 1"):
        return f"before\n# >>> zenix theme <<<\n{body}\n# >>> end zenix theme <<<\nafter\n"

    def test_replaces_the_body_and_keeps_the_markers(self):
        out = theme.replace_block(self.text(), "hash", "new = 2", what="x")
        self.assertEqual(
            out,
            "before\n# >>> zenix theme <<<\nnew = 2\n# >>> end zenix theme <<<\nafter\n",
        )

    def test_leaves_the_surrounding_text_alone(self):
        out = theme.replace_block(self.text(), "hash", "new = 2", what="x")
        self.assertTrue(out.startswith("before\n"))
        self.assertTrue(out.endswith("after\n"))

    def test_is_idempotent(self):
        once = theme.replace_block(self.text(), "hash", "new = 2", what="x")
        twice = theme.replace_block(once, "hash", "new = 2", what="x")
        self.assertEqual(once, twice)

    def test_a_multi_line_body_is_written_whole(self):
        out = theme.replace_block(self.text(), "hash", "a = 1\nb = 2", what="x")
        self.assertIn("a = 1\nb = 2", out)

    def test_an_indented_block_keeps_its_indentation(self):
        src = "x\n  # >>> zenix theme <<<\n  old\n  # >>> end zenix theme <<<\n"
        out = theme.replace_block(src, "hash", "a = 1", what="x")
        self.assertIn("\n  a = 1\n", out)

    def test_a_missing_block_is_refused_rather_than_inserted(self):
        # Guessing where the block belongs would put a palette in the middle of
        # someone's layout. The markers are placed by hand, once.
        with self.assertRaises(ZenixError) as caught:
            theme.replace_block("no markers here\n", "hash", "x", what="some/file")
        self.assertIn("some/file", str(caught.exception))
        self.assertIn("out of sync", str(caught.exception))

    def test_an_unclosed_block_is_refused(self):
        with self.assertRaises(ZenixError):
            theme.replace_block("# >>> zenix theme <<<\nbody\n", "hash", "x", what="f")


class SetKey(unittest.TestCase):
    def test_rewrites_only_the_captured_group(self):
        out = theme.set_key('theme = old\nother = old\n', r"^theme = (\S+)", "new",
                            what="f")
        self.assertEqual(out, "theme = new\nother = old\n")

    def test_only_the_first_match_is_touched(self):
        out = theme.set_key("k = a\nk = a\n", r"^k = (\S+)", "b", what="f")
        self.assertEqual(out, "k = b\nk = a\n")

    def test_a_missing_key_is_refused(self):
        with self.assertRaises(ZenixError) as caught:
            theme.set_key("nothing\n", r"^theme = (\S+)", "x", what="some/file")
        self.assertIn("some/file", str(caught.exception))


class RewriteLazygit(unittest.TestCase):
    """lazygit rewrites this file wholesale, so the anchor is YAML structure."""

    def config(self):
        return (
            "gui:\n"
            "  scrollHeight: 2\n"
            "  theme:\n"
            "    activeBorderColor:\n"
            "      - '#oldold'\n"
            "      - bold\n"
            "    defaultFgColor:\n"
            "      - '#oldold'\n"
            "  commitLength:\n"
            "    show: true\n"
            "git:\n"
            "  autoFetch: true\n"
        )

    def rewritten(self):
        t = theme.Theme("fixture", json.loads(json.dumps(FIXTURE_THEME)))
        return theme.rewrite_lazygit(self.config(), t)

    def test_the_surrounding_config_survives(self):
        out = self.rewritten()
        for line in ("gui:", "  scrollHeight: 2", "  commitLength:",
                     "    show: true", "git:", "  autoFetch: true"):
            self.assertIn(line + "\n", out)

    def test_the_old_theme_values_are_gone(self):
        self.assertNotIn("#oldold", self.rewritten())

    def test_every_theme_key_is_written(self):
        out = self.rewritten()
        for key, _role, _attr in theme.LAZYGIT_THEME_KEYS:
            self.assertIn(f"    {key}:\n", out)

    def test_bold_is_kept_only_where_it_belongs(self):
        out = self.rewritten()
        active = out.split("activeBorderColor:\n")[1]
        self.assertIn("      - bold\n", active.split("    search")[0])

    def test_is_idempotent(self):
        t = theme.Theme("fixture", json.loads(json.dumps(FIXTURE_THEME)))
        once = theme.rewrite_lazygit(self.config(), t)
        self.assertEqual(once, theme.rewrite_lazygit(once, t))

    def test_a_config_without_a_theme_block_is_refused(self):
        t = theme.Theme("fixture", json.loads(json.dumps(FIXTURE_THEME)))
        with self.assertRaises(ZenixError):
            theme.rewrite_lazygit("gui:\n  scrollHeight: 2\n", t)


class RewriteHyprlock(unittest.TestCase):
    """`color` means different things per block, and there are two labels."""

    def config(self):
        return (
            "background {\n"
            "    monitor =\n"
            "    path = /home/x/Pictures/wallpaper/a.jpg\n"
            "    color = rgba(0, 0, 0, 1.0)\n"
            "}\n"
            "\n"
            "input-field {\n"
            "    outer_color = rgba(000000ff)\n"
            "    inner_color = rgba(000000ff)\n"
            "    font_color = rgba(000000ff)\n"
            '    placeholder_text = <span foreground="##000000">Password</span>\n'
            "}\n"
            "\n"
            "label {\n"
            "    color = rgba(000000ff)\n"
            "    font_size = 90\n"
            "}\n"
            "\n"
            "label {\n"
            "    color = rgba(000000ff)\n"
            "    font_size = 20\n"
            "}\n"
        )

    def rewritten(self):
        t = theme.Theme("fixture", json.loads(json.dumps(FIXTURE_THEME)))
        return theme.rewrite_hyprlock(self.config(), t)

    def test_the_wallpaper_path_is_never_touched(self):
        # `zenix wallpaper` and install.sh own that line.
        self.assertIn("path = /home/x/Pictures/wallpaper/a.jpg", self.rewritten())

    def test_the_two_label_blocks_get_different_colours(self):
        out = self.rewritten()
        clock, date = FIXTURE_THEME["hyprlock"]["clock"], FIXTURE_THEME["hyprlock"]["date"]
        blocks = out.split("label {")
        self.assertIn(clock, blocks[1])
        self.assertIn(date, blocks[2])

    def test_the_background_colour_keeps_the_decimal_spelling(self):
        self.assertIn(f"color = {FIXTURE_THEME['hyprlock']['bg']}", self.rewritten())

    def test_the_pango_placeholder_keeps_its_doubled_hash(self):
        # ## is hyprlang's escape for a literal #, and the value is written
        # as a literal rather than through a variable precisely so that the
        # escaping cannot be got wrong.
        out = self.rewritten()
        self.assertIn('foreground="##010203"', out)
        self.assertIn(">Password</span>", out)

    def test_non_colour_keys_survive(self):
        out = self.rewritten()
        self.assertIn("font_size = 90", out)
        self.assertIn("font_size = 20", out)

    def test_is_idempotent(self):
        t = theme.Theme("fixture", json.loads(json.dumps(FIXTURE_THEME)))
        once = theme.rewrite_hyprlock(self.config(), t)
        self.assertEqual(once, theme.rewrite_hyprlock(once, t))

    def test_a_config_missing_a_colour_key_is_refused(self):
        t = theme.Theme("fixture", json.loads(json.dumps(FIXTURE_THEME)))
        with self.assertRaises(ZenixError) as caught:
            theme.rewrite_hyprlock("background {\n    color = rgba(0,0,0,1.0)\n}\n", t)
        self.assertIn("out of sync", str(caught.exception))


class LoadTheme(RepoCase):
    def test_loads_every_section(self):
        t = theme.load(self.repo, "fixture")
        for section in theme.Theme.SECTIONS:
            self.assertTrue(hasattr(t, section), section)

    def test_names_lists_the_directory(self):
        make_theme(self.root, "other")
        self.assertEqual(theme.names(self.repo), ["fixture", "other"])

    def test_an_unknown_theme_names_what_is_available(self):
        with self.assertRaises(ZenixError) as caught:
            theme.load(self.repo, "nope")
        self.assertIn("fixture", str(caught.exception))

    def test_a_truncated_section_is_refused(self):
        data = json.loads(json.dumps(FIXTURE_THEME))
        del data["desktop"]
        (self.root / "themes" / "broken.json").write_text(json.dumps(data))
        with self.assertRaises(ZenixError) as caught:
            theme.load(self.repo, "broken")
        self.assertIn("desktop", str(caught.exception))

    def test_invalid_json_says_so(self):
        (self.root / "themes" / "bad.json").write_text("{not json")
        with self.assertRaises(ZenixError) as caught:
            theme.load(self.repo, "bad")
        self.assertIn("not valid JSON", str(caught.exception))

    def test_a_missing_role_names_the_theme_and_the_path(self):
        t = theme.load(self.repo, "fixture")
        with self.assertRaises(ZenixError) as caught:
            t["editor.nonexistent"]
        self.assertIn("fixture", str(caught.exception))
        self.assertIn("editor.nonexistent", str(caught.exception))


class Renderers(RepoCase):
    def theme(self):
        return theme.load(self.repo, "fixture")

    def test_every_generated_file_ends_in_exactly_one_newline(self):
        for path, text in theme.plan(self.theme(), self.repo).items():
            with self.subTest(path=path.name):
                self.assertTrue(text.endswith("\n"))
                self.assertFalse(text.endswith("\n\n"))

    def test_ghostty_writes_all_sixteen_slots(self):
        out = theme.render_ghostty_theme(self.theme())
        for i, colour in enumerate(FIXTURE_THEME["terminal"]["palette"]):
            self.assertIn(f"palette = {i}={colour}", out)

    def test_btop_keeps_main_bg_empty_for_the_terminal_transparency(self):
        self.assertIn('theme[main_bg]=""', theme.render_btop_theme(self.theme()))

    def test_btop_shares_its_meter_colours_with_the_bar(self):
        # The README's rule: the meter you click and the box it opens are the
        # same colour.
        out = theme.render_btop_theme(self.theme())
        self.assertIn(f'theme[cpu_start]="{FIXTURE_THEME["desktop"]["status_good"]}"', out)
        self.assertIn(f'theme[cpu_end]="{FIXTURE_THEME["desktop"]["status_bad"]}"', out)

    def test_btop_reuses_one_ramp_for_free_and_download(self):
        out = theme.render_btop_theme(self.theme())
        ramp = FIXTURE_THEME["btop_ramps"]["green"]
        self.assertIn(f'theme[free_end]="{ramp[2]}"', out)
        self.assertIn(f'theme[download_end]="{ramp[2]}"', out)

    def test_the_nvim_palette_carries_the_light_or_dark_flag(self):
        out = theme.render_nvim_palette(self.theme())
        self.assertIn('background = "dark",', out)

    def test_the_nvim_palette_includes_the_roles_init_lua_needs(self):
        out = theme.render_nvim_palette(self.theme())
        for role in ("indent_marker", "backdrop", "comment", "diff_add"):
            self.assertIn(f"  {role} = ", out)

    def test_color_qml_spells_translucent_roles_with_their_alpha(self):
        out = theme.render_shell_color(self.theme())
        self.assertIn(f'background: "{FIXTURE_THEME["desktop"]["card"]}"', out)

    def test_color_qml_exposes_the_whole_wash_ladder(self):
        out = theme.render_shell_color(self.theme())
        for name in ("washFaint", "washDim", "washSoft", "wash", "washBorder",
                     "washHover", "washStrong", "washBold"):
            self.assertIn(f"property color {name}:", out)

    def test_the_qt_scheme_has_twenty_one_roles_in_three_groups(self):
        out = theme.render_qt6ct_colors(self.theme())
        for group in ("active_colors", "disabled_colors", "inactive_colors"):
            line = next(ln for ln in out.splitlines() if ln.startswith(group))
            self.assertEqual(len(line.split("=", 1)[1].split(",")), 21, group)

    def test_a_stock_qt_scheme_is_used_verbatim_and_generates_no_file(self):
        make_theme(self.root, "stock")
        path = self.root / "themes" / "stock.json"
        data = json.loads(path.read_text())
        data["apps"]["qt_scheme"] = "/usr/share/qt6ct/colors/darker.conf"
        path.write_text(json.dumps(data))
        t = theme.load(self.repo, "stock")
        self.assertFalse(theme.generates_qt_colors(t))
        self.assertEqual(theme.qt_scheme_path(t), "/usr/share/qt6ct/colors/darker.conf")

    def test_a_generated_qt_scheme_is_named_with_a_home_placeholder(self):
        # qt6ct resolves the path absolutely and expands nothing, so a real
        # path here would bake one machine's username into the repo.
        t = self.theme()
        self.assertTrue(theme.qt_scheme_path(t).startswith(theme.HOME_PLACEHOLDER))
        self.assertNotIn(str(Path.home()), theme.qt_scheme_path(t))

    def test_a_missing_optional_surface_is_skipped_not_fatal(self):
        # grub/ and sddm/ are optional parts of the setup.
        files = theme.plan(self.theme(), self.repo)
        self.assertFalse(any("grub" in str(p) for p in files))


@real_only
class ShippedThemes(unittest.TestCase):
    """Invariants every theme in themes/ has to satisfy."""

    @classmethod
    def setUpClass(cls):
        cls.repo = Repo(REAL)
        cls.names = theme.names(cls.repo)
        cls.themes = {n: theme.load(cls.repo, n) for n in cls.names}
        cls.reference = cls.themes["xcode-zenix"]

    def test_the_four_catppuccin_flavours_and_the_original_are_present(self):
        self.assertEqual(
            set(self.names),
            {"xcode-zenix", "catppuccin-mocha", "catppuccin-macchiato",
             "catppuccin-frappe", "catppuccin-latte"},
        )

    def test_every_theme_declares_exactly_the_same_roles(self):
        # Set equality both ways: a missing role leaves a surface on the old
        # palette, and a typo'd extra one is silently never read.
        for name, t in self.themes.items():
            for section in theme.Theme.SECTIONS:
                want, got = getattr(self.reference, section), getattr(t, section)
                if not isinstance(want, dict):
                    continue
                with self.subTest(theme=name, section=section):
                    self.assertEqual(set(want), set(got))

    def test_every_colour_is_a_hex_or_a_spelling_the_target_understands(self):
        import re
        ok = re.compile(r"^(#[0-9a-f]{6}|#[0-9a-f]{8}|##[0-9a-f]{6}|"
                        r"rgba\([0-9a-f]{8}\)|rgba\(\d+, \d+, \d+, [\d.]+\)|"
                        r"0x[0-9a-f]{8})$")
        for name, t in self.themes.items():
            for section in theme.Theme.SECTIONS:
                values = getattr(t, section)
                if section in ("meta", "apps") or not isinstance(values, dict):
                    continue
                for key, value in values.items():
                    if key.startswith("_"):
                        continue
                    for v in (value if isinstance(value, list) else [value]):
                        with self.subTest(theme=name, key=f"{section}.{key}"):
                            self.assertRegex(v, ok)

    def test_the_bar_and_btop_agree_on_the_meter_colours(self):
        for name, t in self.themes.items():
            with self.subTest(theme=name):
                self.assertEqual(t.btop_ramps["accent"][2], t.desktop["accent"])
                self.assertEqual(t.btop_ramps["green"][2], t.desktop["status_good"])

    def test_the_editor_colour_aliases_hold(self):
        for name, t in self.themes.items():
            with self.subTest(theme=name):
                self.assertEqual(t.editor["red"], t.editor["salmon"])
                self.assertEqual(t.editor["yellow"], t.editor["sand"])
                self.assertEqual(t.editor["blue"], t.editor["cyan"])

    def test_the_accent_is_legible_under_whatever_sits_on_it(self):
        """The trap: Sonoma's accent is dark and carries white, blue cannot.

        3:1 rather than 4.5:1 because everything that sits on an accent fill
        here is a bold glyph at bar size -- waybar's workspace number, the
        greeter's highlighted row -- which is WCAG's large-text case. The
        threshold still separates cleanly: the shipped themes measure 3.65
        (xcode-zenix), 4.34 (latte) and 8.9 (the dark flavours), while leaving
        `on_accent` white over a Catppuccin blue -- the mistake this guards
        against -- measures 2.1 to 2.3.
        """
        for name, t in self.themes.items():
            with self.subTest(theme=name):
                self.assertGreaterEqual(
                    contrast(t.desktop["accent"], t.desktop["on_accent"]), 3.0
                )

    def test_body_text_is_legible_on_its_own_background(self):
        for name, t in self.themes.items():
            with self.subTest(theme=name):
                self.assertGreaterEqual(contrast(t.editor["bg"], t.editor["fg"]), 7.0)
                self.assertGreaterEqual(
                    contrast(t.desktop["surface"], t.desktop["foreground"]), 4.5
                )

    def test_light_and_dark_are_declared_consistently(self):
        for name, t in self.themes.items():
            with self.subTest(theme=name):
                self.assertIn(t.meta["background"], ("dark", "light"))
                # A theme that calls itself dark but has a light base would
                # send nvim's `background` and the gsettings colour scheme the
                # wrong way round.
                lum = luminance(t.editor["bg"])
                self.assertEqual(t.is_dark, lum < 0.5)

    def test_every_theme_renders_every_surface(self):
        for name, t in self.themes.items():
            with self.subTest(theme=name):
                files = theme.plan(t, self.repo)
                self.assertGreater(len(files), 15)

    def test_the_committed_configs_match_what_the_generator_writes(self):
        """The headline guard: selecting a theme is a no-op when it is current.

        If this fails, either someone hand-edited a generated file or a
        renderer drifted -- and `zenix theme set` would quietly revert them.
        """
        name = self.repo.read_shell_var("THEME_NAME")
        self.assertIn(name, self.names)
        for path, text in theme.plan(self.themes[name], self.repo).items():
            with self.subTest(path=str(path.relative_to(REAL))):
                self.assertTrue(path.is_file())
                self.assertEqual(path.read_text(), text)


def luminance(colour: str) -> float:
    def channel(v: int) -> float:
        s = v / 255
        return s / 12.92 if s <= 0.03928 else ((s + 0.055) / 1.055) ** 2.4

    h = colour.lstrip("#")
    if len(h) == 8:
        h = h[2:]
    r, g, b = (channel(int(h[i:i + 2], 16)) for i in (0, 2, 4))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a: str, b: str) -> float:
    la, lb = luminance(a), luminance(b)
    lo, hi = sorted((la, lb))
    return (hi + 0.05) / (lo + 0.05)


if __name__ == "__main__":
    unittest.main()
