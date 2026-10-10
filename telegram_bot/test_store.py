from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from catalog import validate_function_id
from store import FunctionStore


class FunctionStoreTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name)
        self.store = FunctionStore(self.root)

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def test_texture_functions_have_stable_ids_and_labels(self) -> None:
        expected = {
            "textura.bolsonaro": ("TEXTURA - BOLSONARO", "Personagem Maro"),
            "textura.instaplayer1": ("TEXTURA - INSTAPLAYER 1", "Personagem SANTINO"),
            "textura.instaplayer2": ("TEXTURA - INSTAPLAYER 2", "Personagem DIMITRI"),
            "textura.mandela": ("TEXTURA - MANDELA", "Personagem Alok Despertado"),
        }
        for function_id, (name, description) in expected.items():
            with self.subTest(function_id=function_id):
                definition = validate_function_id(function_id)
                self.assertEqual(definition.name, name)
                self.assertEqual(definition.description, description)
                self.assertEqual(definition.group_id, "texture")
        with self.assertRaises(ValueError):
            validate_function_id("textura.toguro")

    @staticmethod
    def files(count: int) -> list[dict[str, object]]:
        return [
            {
                "data": f"content-{index}".encode(),
                "target_filename": f"Documents/file-{index}.dat",
            }
            for index in range(1, count + 1)
        ]

    def test_esp_publishes_exactly_the_uploaded_file_count(self) -> None:
        published = self.store.publish_multi_raw(
            "panel.ffh4x",
            self.files(7),
            target_bundle_id="com.example.game",
        )

        self.assertEqual(len(published["raw_files"]), 7)
        self.assertEqual(published["package_format"], "raw_multi")
        self.assertTrue(all(self.store.package_path_for_name(Path(item["package"]).name) for item in published["raw_files"]))

    def test_esp_requires_at_least_one_file(self) -> None:
        with self.assertRaises(ValueError):
            self.store.publish_multi_raw(
                "panel.ffh4x",
                [],
                target_bundle_id="com.example.game",
            )

    def test_removed_reset_guest_cannot_be_published(self) -> None:
        with self.assertRaises(ValueError):
            self.store.publish_multi_raw(
                "game.reset_guest",
                self.files(2),
                target_bundle_id="com.example.game",
            )

    def test_replacing_or_deleting_multi_publication_removes_all_files(self) -> None:
        published = self.store.publish_multi_raw(
            "panel.ffh4x",
            self.files(3),
            target_bundle_id="com.example.game",
        )
        old_paths = [self.store.package_path_for_name(Path(item["package"]).name) for item in published["raw_files"]]
        self.assertTrue(all(path is not None and path.is_file() for path in old_paths))

        self.store.delete_package("panel.ffh4x")
        entry = self.store.get("panel.ffh4x")
        self.assertEqual(entry["raw_files"], [])
        self.assertTrue(all(path is not None and not path.exists() for path in old_paths))

    def test_switching_multi_publication_to_single_clears_stale_raw_files(self) -> None:
        published = self.store.publish_multi_raw(
            "panel.ffh4x",
            self.files(4),
            target_bundle_id="com.example.game",
        )
        old_paths = [self.store.package_path_for_name(Path(item["package"]).name) for item in published["raw_files"]]

        entry = self.store.publish(
            "panel.ffh4x",
            b"replacement",
            package_format="raw",
            target_bundle_id="com.example.game",
            target_filename="config.dat",
        )

        self.assertEqual(entry["raw_files"], [])
        self.assertTrue(all(path is not None and not path.exists() for path in old_paths))

    def test_republishing_fewer_esp_files_removes_unselected_old_files(self) -> None:
        first = self.store.publish_multi_raw(
            "panel.ffh4x",
            self.files(7),
            target_bundle_id="com.example.game",
        )
        old_paths = [self.store.package_path_for_name(Path(item["package"]).name) for item in first["raw_files"]]

        second = self.store.publish_multi_raw(
            "panel.ffh4x",
            self.files(3),
            target_bundle_id="com.example.game",
        )

        self.assertEqual(len(second["raw_files"]), 3)
        self.assertTrue(all(path is not None and path.is_file() for path in old_paths[:3]))
        self.assertTrue(all(path is not None and not path.exists() for path in old_paths[3:]))


if __name__ == "__main__":
    unittest.main()
