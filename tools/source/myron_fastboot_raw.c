#include <libusb-1.0/libusb.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MYRON_VID 0x18d1
#define MYRON_PID 0xd00d
#define USB_TIMEOUT_MS 5000

static void die_libusb(const char *what, int rc) {
    fprintf(stderr, "%s: %s\n", what, libusb_error_name(rc));
    exit(1);
}

int main(int argc, char **argv) {
    const char *expected_serial = getenv("MYRON_FASTBOOT_SERIAL");
    if (!expected_serial || expected_serial[0] == '\0') {
        fprintf(stderr,
                "set MYRON_FASTBOOT_SERIAL to the serial printed by adb devices\n");
        return 2;
    }

    const char *command = NULL;
    if (argc == 2 && strcmp(argv[1], "get-current-slot") == 0) {
        command = "getvar:current-slot";
    } else if (argc == 2 && strcmp(argv[1], "get-unlocked") == 0) {
        command = "getvar:unlocked";
    } else if (argc == 3 && strcmp(argv[1], "set-active-a") == 0 &&
               strcmp(argv[2], "I_UNDERSTAND_SET_ACTIVE_A") == 0) {
        command = "set_active:a";
    } else if (argc == 3 && strcmp(argv[1], "set-active-b") == 0 &&
               strcmp(argv[2], "I_UNDERSTAND_SET_ACTIVE_B") == 0) {
        command = "set_active:b";
    } else if (argc == 3 && strcmp(argv[1], "reboot-bootloader") == 0 &&
               strcmp(argv[2], "I_UNDERSTAND_REBOOT") == 0) {
        command = "reboot-bootloader";
    } else if (argc == 3 && strcmp(argv[1], "erase-efisp") == 0 &&
               strcmp(argv[2], "I_UNDERSTAND_ERASE_EFISP") == 0) {
        command = "erase:efisp";
    } else if (argc == 3 && strcmp(argv[1], "reboot-system") == 0 &&
               strcmp(argv[2], "I_UNDERSTAND_REBOOT") == 0) {
        command = "reboot";
    } else {
        fprintf(stderr,
                "usage: %s get-current-slot\n"
                "       %s get-unlocked\n"
                "       %s set-active-a I_UNDERSTAND_SET_ACTIVE_A\n"
                "       %s set-active-b I_UNDERSTAND_SET_ACTIVE_B\n"
                "       %s reboot-bootloader I_UNDERSTAND_REBOOT\n"
                "       %s erase-efisp I_UNDERSTAND_ERASE_EFISP\n"
                "       %s reboot-system I_UNDERSTAND_REBOOT\n",
                argv[0], argv[0], argv[0], argv[0], argv[0], argv[0], argv[0]);
        return 2;
    }

    libusb_context *ctx = NULL;
    int rc = libusb_init(&ctx);
    if (rc != 0) die_libusb("libusb_init", rc);

    libusb_device_handle *handle =
        libusb_open_device_with_vid_pid(ctx, MYRON_VID, MYRON_PID);
    if (!handle) {
        fprintf(stderr, "exact Fastboot USB device %04x:%04x not found\n",
                MYRON_VID, MYRON_PID);
        libusb_exit(ctx);
        return 1;
    }

    unsigned char serial[128] = {0};
    struct libusb_device_descriptor descriptor;
    rc = libusb_get_device_descriptor(libusb_get_device(handle), &descriptor);
    if (rc != 0) die_libusb("get device descriptor", rc);
    rc = libusb_get_string_descriptor_ascii(handle, descriptor.iSerialNumber,
                                             serial, sizeof(serial));
    if (rc < 0) die_libusb("read serial", rc);
    if (strcmp((char *)serial, expected_serial) != 0) {
        fprintf(stderr, "refusing unexpected serial: %s\n", serial);
        libusb_close(handle);
        libusb_exit(ctx);
        return 1;
    }

    struct libusb_config_descriptor *config = NULL;
    rc = libusb_get_active_config_descriptor(libusb_get_device(handle), &config);
    if (rc != 0) die_libusb("get active USB configuration", rc);

    int interface_number = -1;
    unsigned char endpoint_in = 0, endpoint_out = 0;
    for (int i = 0; i < config->bNumInterfaces; ++i) {
        const struct libusb_interface *interface = &config->interface[i];
        for (int a = 0; a < interface->num_altsetting; ++a) {
            const struct libusb_interface_descriptor *alt = &interface->altsetting[a];
            if (alt->bInterfaceClass != 0xff || alt->bInterfaceSubClass != 0x42 ||
                alt->bInterfaceProtocol != 0x03) continue;
            interface_number = alt->bInterfaceNumber;
            for (int e = 0; e < alt->bNumEndpoints; ++e) {
                const struct libusb_endpoint_descriptor *ep = &alt->endpoint[e];
                if ((ep->bmAttributes & LIBUSB_TRANSFER_TYPE_MASK) !=
                    LIBUSB_TRANSFER_TYPE_BULK) continue;
                if (ep->bEndpointAddress & LIBUSB_ENDPOINT_IN)
                    endpoint_in = ep->bEndpointAddress;
                else
                    endpoint_out = ep->bEndpointAddress;
            }
        }
    }
    libusb_free_config_descriptor(config);
    if (interface_number < 0 || endpoint_in == 0 || endpoint_out == 0) {
        fprintf(stderr, "Fastboot USB interface was not found\n");
        libusb_close(handle);
        libusb_exit(ctx);
        return 1;
    }

    rc = libusb_claim_interface(handle, interface_number);
    if (rc != 0) die_libusb("claim Fastboot interface", rc);

    int transferred = 0;
    rc = libusb_bulk_transfer(handle, endpoint_out, (unsigned char *)command,
                              (int)strlen(command), &transferred, USB_TIMEOUT_MS);
    if (rc != 0) die_libusb("send Fastboot command", rc);
    if (transferred != (int)strlen(command)) {
        fprintf(stderr, "short Fastboot command write\n");
        return 1;
    }

    int result = 1;
    for (;;) {
        unsigned char response[65] = {0};
        transferred = 0;
        rc = libusb_bulk_transfer(handle, endpoint_in, response, 64, &transferred,
                                  USB_TIMEOUT_MS);
        if (rc != 0) die_libusb("read Fastboot response", rc);
        response[transferred] = '\0';
        if (transferred < 4) {
            fprintf(stderr, "short Fastboot response\n");
            break;
        }
        if (memcmp(response, "INFO", 4) == 0 || memcmp(response, "TEXT", 4) == 0) {
            printf("%.*s\n", transferred - 4, response + 4);
            continue;
        }
        if (memcmp(response, "OKAY", 4) == 0) {
            printf("OKAY%.*s\n", transferred - 4, response + 4);
            result = 0;
            break;
        }
        if (memcmp(response, "FAIL", 4) == 0) {
            fprintf(stderr, "FAIL%.*s\n", transferred - 4, response + 4);
            result = 3;
            break;
        }
        fprintf(stderr, "unexpected Fastboot response: %.*s\n", transferred, response);
        break;
    }

    libusb_release_interface(handle, interface_number);
    libusb_close(handle);
    libusb_exit(ctx);
    return result;
}
