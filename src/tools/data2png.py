import struct
import sys

from PIL import Image


def main() -> int:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} input.data output.png", file=sys.stderr)
        return 1

    input_path = sys.argv[1]
    output_path = sys.argv[2]

    with open(input_path, "rb") as source:
        header = source.read(8)

        if len(header) != 8:
            raise ValueError("The image header is incomplete")

        width, height = struct.unpack("<ii", header)
        pixel_data = source.read()

    expected_size = width * height * 4

    if width <= 0 or height <= 0 or len(pixel_data) != expected_size:
        raise ValueError("The image dimensions do not match the pixel data")

    image = Image.frombytes("RGBA", (width, height), pixel_data)
    image.save(output_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
