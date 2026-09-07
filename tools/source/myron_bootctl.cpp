#include <sys/system_properties.h>
#include <sys/utsname.h>
#include <unistd.h>

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <memory>
#include <optional>
#include <string>

namespace aidl::android::hardware::boot {
enum class MergeStatus : int8_t {};
}

namespace android::hal {
struct CommandResult {
    bool success;
    std::string errMsg;
    constexpr bool IsOk() const { return success; }
};

enum class BootControlVersion { BOOTCTL_V1_0, BOOTCTL_V1_1, BOOTCTL_V1_2, BOOTCTL_AIDL };

class BootControlClient {
  public:
    using MergeStatus = aidl::android::hardware::boot::MergeStatus;
    virtual ~BootControlClient() = default;
    virtual BootControlVersion GetVersion() const = 0;
    virtual int32_t GetNumSlots() const = 0;
    virtual int32_t GetCurrentSlot() const = 0;
    virtual std::string GetSuffix(int32_t slot) const = 0;
    virtual std::optional<bool> IsSlotBootable(int32_t slot) const = 0;
    virtual CommandResult MarkSlotUnbootable(int32_t slot) = 0;
    virtual CommandResult SetActiveBootSlot(int32_t slot) = 0;
    virtual std::optional<bool> IsSlotMarkedSuccessful(int32_t slot) const = 0;
    virtual CommandResult MarkBootSuccessful() = 0;
    virtual MergeStatus getSnapshotMergeStatus() const = 0;
    virtual CommandResult SetSnapshotMergeStatus(MergeStatus status) = 0;
    virtual int32_t GetActiveBootSlot() const = 0;
    static std::unique_ptr<BootControlClient> WaitForService();
};
}  // namespace android::hal

static constexpr char kExpectedModel[] = "25102PCBEG";
static constexpr char kExpectedDevice[] = "myron";
static constexpr char kExpectedBuild[] = "OS3.0.301.0.WPMEUXM";
static constexpr char kExpectedKernel[] =
    "6.12.23-android16-5-g5a0e85dd9db0-ab14499855-4k";

[[noreturn]] static void fail(const char* message) {
    std::fprintf(stderr, "ERROR: %s\n", message);
    std::exit(1);
}

static std::string property(const char* name) {
    char value[PROP_VALUE_MAX] = {};
    __system_property_get(name, value);
    return value;
}

static const char* optional_bool(const std::optional<bool>& value) {
    if (!value.has_value()) return "error";
    return *value ? "yes" : "no";
}

static bool selinux_is_permissive() {
    FILE* file = std::fopen("/sys/fs/selinux/enforce", "re");
    if (!file) return false;
    const int value = std::fgetc(file);
    std::fclose(file);
    return value == '0';
}

static void verify_exact_target() {
    const uid_t uid = geteuid();
    if (uid != 0 && !(uid == 2000 && selinux_is_permissive()))
        fail("set-active requires root or UID 2000 while SELinux is permissive");
    if (property("ro.product.model") != kExpectedModel) fail("wrong model");
    if (property("ro.product.device") != kExpectedDevice) fail("wrong device");
    if (property("ro.build.version.incremental") != kExpectedBuild) fail("wrong build");
    if (property("ro.boot.slot_suffix") != "_b") fail("current Android slot is not _b");
    struct utsname uts = {};
    if (uname(&uts) != 0 || std::string(uts.release) != kExpectedKernel) fail("wrong kernel");
}

static void print_state(android::hal::BootControlClient& client) {
    const int32_t count = client.GetNumSlots();
    const int32_t current = client.GetCurrentSlot();
    const int32_t active = client.GetActiveBootSlot();
    std::printf("version=%d slots=%d current=%d active=%d\n",
                static_cast<int>(client.GetVersion()), count, current, active);
    for (int32_t slot = 0; slot < count && slot < 4; ++slot) {
        const std::string suffix = client.GetSuffix(slot);
        const auto bootable = client.IsSlotBootable(slot);
        const auto successful = client.IsSlotMarkedSuccessful(slot);
        std::printf("slot=%d suffix=%s bootable=%s successful=%s\n", slot,
                    suffix.c_str(), optional_bool(bootable), optional_bool(successful));
    }
}

int main(int argc, char** argv) {
    enum class Operation { Inspect, SetA, SetB } operation;
    if (argc == 2 && std::string(argv[1]) == "inspect") {
        operation = Operation::Inspect;
    } else if (argc == 3 && std::string(argv[1]) == "set-active-a" &&
               std::string(argv[2]) == "I_UNDERSTAND_SET_ACTIVE_A") {
        operation = Operation::SetA;
    } else if (argc == 3 && std::string(argv[1]) == "set-active-b" &&
               std::string(argv[2]) == "I_UNDERSTAND_SET_ACTIVE_B") {
        operation = Operation::SetB;
    } else {
        std::fprintf(stderr,
                     "usage: %s inspect\n"
                     "       %s set-active-a I_UNDERSTAND_SET_ACTIVE_A\n"
                     "       %s set-active-b I_UNDERSTAND_SET_ACTIVE_B\n",
                     argv[0], argv[0], argv[0]);
        return 2;
    }

    auto client = android::hal::BootControlClient::WaitForService();
    if (!client) fail("boot-control HAL is unavailable");
    print_state(*client);
    if (operation == Operation::Inspect) return 0;

    verify_exact_target();
    if (client->GetNumSlots() != 2) fail("expected exactly two slots");
    if (client->GetCurrentSlot() != 1) fail("expected to be running from slot B");
    if (client->GetSuffix(0) != "_a" || client->GetSuffix(1) != "_b")
        fail("unexpected slot suffix mapping");

    const int32_t target = operation == Operation::SetA ? 0 : 1;
    const auto result = client->SetActiveBootSlot(target);
    if (!result.success) {
        std::fprintf(stderr, "ERROR: SetActiveBootSlot(%d) failed: %s\n", target,
                     result.errMsg.c_str());
        return 1;
    }
    if (client->GetActiveBootSlot() != target) fail("HAL returned success but active slot differs");
    std::printf("SetActiveBootSlot(%d) succeeded and readback matched.\n", target);
    print_state(*client);
    return 0;
}
