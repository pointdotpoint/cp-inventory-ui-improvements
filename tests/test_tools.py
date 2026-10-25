import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import build_installed_poses


class PoseParserTests(unittest.TestCase):
    def test_female_lists_accept_both_yaml_indentation_styles(self):
        for indent in ("", "  "):
            with self.subTest(indent=indent), tempfile.TemporaryDirectory() as folder:
                path = Path(folder) / "poses.yaml"
                path.write_text(
                    "photo_mode.character.femalePoses:\n"
                    f"{indent}- !append-once PhotoModePoses.halt_i_s1\n"
                    f"{indent}- !append PhotoModePoses.halt_i_s2\n"
                    "photo_mode.character.malePoses:\n"
                    "- !append PhotoModePoses.male_only\n"
                    "PhotoModePoses.halt_i_s1:\n"
                    "  animationName: halt_i\n"
                )
                with patch.object(build_installed_poses, "tweak_files", return_value=[str(path)]):
                    poses, _, order = build_installed_poses.parse_tweaks()
                self.assertEqual(order, ["halt_i_s1", "halt_i_s2"])
                self.assertEqual(poses["halt_i_s1"]["animationName"], "halt_i")

    def test_animation_packs_are_read_last_and_do_not_take_pose_pack_clips(self):
        with tempfile.TemporaryDirectory() as game:
            tweaks = Path(game) / "r6" / "tweaks"
            (tweaks / "PhotoModeUIImprovements").mkdir(parents=True)
            (tweaks / "sitting").mkdir()
            (tweaks / "PhotoModeUIImprovements" / "animations.yaml").write_text(
                "PhotoModePoseCategories.PMUI_Anim_Sitting_F:\n"
                '  displayName: "Animations: Sitting"\n'
                "PhotoModePoses.PMUI_Anim_0_F:\n"
                "  animationName: shared_clip\n"
                "  category: PhotoModePoseCategories.PMUI_Anim_Sitting_F\n"
                "PhotoModePoses.PMUI_Anim_1_F:\n"
                "  animationName: amm_only_clip\n"
                "  category: PhotoModePoseCategories.PMUI_Anim_Sitting_F\n"
                "photo_mode.character.femalePoses: &PMUIAnimF\n"
                "  - !append PhotoModePoses.PMUI_Anim_0_F\n"
                "  - !append PhotoModePoses.PMUI_Anim_1_F\n"
            )
            (tweaks / "sitting" / "pack.yaml").write_text(
                "PhotoModePoseCategories.sitting_pack:\n"
                "  displayName: Sitting Collection\n"
                "PhotoModePoses.sit_1:\n"
                "  animationName: shared_clip\n"
                "  category: PhotoModePoseCategories.sitting_pack\n"
                "photo_mode.character.femalePoses:\n"
                "  - !append PhotoModePoses.sit_1\n"
            )
            with patch.object(build_installed_poses, "GAME", game):
                groups = build_installed_poses.mod_packs(set())
        self.assertEqual(groups, [
            ("Sitting Collection", ["shared_clip"]),
            ("Animations: Sitting", ["amm_only_clip"]),
        ])


class PreviewTargetTests(unittest.TestCase):
    def test_both_cameras_and_the_texture_get_the_wide_portrait_target(self):
        import build_preview_target as target
        camera = {"$type": "entRenderToTextureCameraComponent", "fov": 32,
                  "resolutionWidth": 720, "resolutionHeight": 720}
        entity = {"Data": {"RootChunk": {"components": [dict(camera)],
                                         "compiledData": {"Data": {"Chunks": [{"$type": "other"}, dict(camera)]}}}}}
        self.assertEqual(target.patch_target(entity), 2)
        for found in (entity["Data"]["RootChunk"]["components"][0],
                      entity["Data"]["RootChunk"]["compiledData"]["Data"]["Chunks"][1]):
            self.assertEqual((found["fov"], found["resolutionWidth"], found["resolutionHeight"]), (99, 2880, 5760))
        texture = {"Data": {"RootChunk": {"width": 720, "height": 720, "scaleToViewport": 1}}}
        target.patch_texture(texture)
        self.assertEqual(texture["Data"]["RootChunk"], {"width": 2880, "height": 5760, "scaleToViewport": 0})


class SamplerTests(unittest.TestCase):
    def test_gpu_process_is_reaped_when_sampling_is_interrupted(self):
        spec = importlib.util.spec_from_file_location("sampler", ROOT / "probe" / "sampler.py")
        sampler = importlib.util.module_from_spec(spec)
        with patch.object(sys, "argv", ["sampler.py", "0"]):
            spec.loader.exec_module(sampler)
        gpu = MagicMock()
        with patch.object(sampler, "find_game", return_value=123), \
                patch.object(sampler.subprocess, "Popen", return_value=gpu), \
                patch.object(sampler.os, "set_blocking"), \
                patch.object(sampler, "read_threads", side_effect=KeyboardInterrupt):
            with self.assertRaises(KeyboardInterrupt):
                sampler.main()
        gpu.terminate.assert_called_once()
        gpu.wait.assert_called_once()


if __name__ == "__main__":
    unittest.main()
