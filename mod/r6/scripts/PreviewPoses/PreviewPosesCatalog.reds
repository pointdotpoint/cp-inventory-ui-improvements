// Reads the installed pose list from TweakDB (mod/r6/tweaks/PreviewPoses/poses.yaml).
// Index i in those arrays is paperdoll switch input i+1.
// Pose 0 is the vanilla preview pose, pack -1, and is not stored in the arrays.
// Instance fields on purpose: a static function returning an array came back empty here.
public class PreviewPosesCatalog {
    private let m_loaded: Bool;
    private let m_anims: array<CName>;
    private let m_packOf: array<Int32>;
    private let m_packNames: array<String>;

    private func Load() -> Void {
        if this.m_loaded {
            return;
        }
        this.m_loaded = true;
        let anims: array<String> = TweakDBInterface.GetStringArray(t"PreviewPoses.list.animations");
        let packNames: array<String> = TweakDBInterface.GetStringArray(t"PreviewPoses.list.packNames");
        let packs: array<String> = TweakDBInterface.GetStringArray(t"PreviewPoses.list.packs");
        let count: Int32 = ArraySize(anims);
        if ArraySize(packNames) < count {
            count = ArraySize(packNames);
        }
        if ArraySize(packs) < count {
            count = ArraySize(packs);
        }
        let index: Int32 = 0;
        while index < count {
            ArrayPush(this.m_anims, StringToName(anims[index]));
            let pack: Int32 = StringToInt(packs[index], -1);
            ArrayPush(this.m_packOf, pack);
            if pack >= 0 {
                while ArraySize(this.m_packNames) <= pack {
                    ArrayPush(this.m_packNames, "");
                }
                if Equals(this.m_packNames[pack], "") {
                    this.m_packNames[pack] = packNames[index];
                }
            }
            index += 1;
        }
    }

    public func Count() -> Int32 {
        this.Load();
        return ArraySize(this.m_anims) + 1;
    }

    // 0 is the vanilla preview animation and has no name.
    public func Animation(index: Int32) -> CName {
        this.Load();
        if index <= 0 || index > ArraySize(this.m_anims) {
            return n"None";
        }
        return this.m_anims[index - 1];
    }

    public func PackCount() -> Int32 {
        this.Load();
        return ArraySize(this.m_packNames);
    }

    // Pack of a pose. Pose 0 (vanilla) and any unknown index return -1.
    public func Pack(index: Int32) -> Int32 {
        this.Load();
        if index <= 0 || index > ArraySize(this.m_packOf) {
            return -1;
        }
        return this.m_packOf[index - 1];
    }

    public func PackName(packIndex: Int32) -> String {
        this.Load();
        if packIndex < 0 || packIndex >= ArraySize(this.m_packNames) {
            return "";
        }
        return this.m_packNames[packIndex];
    }
}
