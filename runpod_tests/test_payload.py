import json
import base64

# Load the workflow
with open("Subject_Destination_API.json", "r") as f:
    workflow = json.load(f)

# Helper function to read an image and convert it to base64
def file_to_b64(filepath):
    # If the file doesn't exist just return a dummy base64 string for testing purposes
    # so the script doesn't crash if you don't have the exact image files locally.
    try:
        with open(filepath, "rb") as img_file:
            return base64.b64encode(img_file.read()).decode('utf-8')
    except FileNotFoundError:
        print(f"Warning: {filepath} not found. Using dummy base64 data for testing.")
        return "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII="

# Build the payload
payload = {
    "input": {
        "workflow": workflow,
        "images": [
            {
                "name": "scene_destination.png",
                "image": file_to_b64("scene_destination.png")
            },
            {
                "name": "curtain_mask.png",
                "image": file_to_b64("curtain_mask.png")
            },
            {
                "name": "fabric_swatch.png",
                "image": file_to_b64("fabric_swatch.png")
            }
        ]
    }
}

# Write the payload to a JSON file
with open("runpod_test_payload.json", "w") as f:
    json.dump(payload, f)

print("Generated runpod_test_payload.json!")
