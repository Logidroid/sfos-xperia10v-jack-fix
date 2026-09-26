#!/usr/bin/env python3
"""Add wired headset/headphone device ports to Android primary audio policy XML."""
from pathlib import Path
import sys


def patch(path: Path) -> None:
    text = path.read_text(encoding="utf-8")

    if "AUDIO_DEVICE_OUT_WIRED_HEADPHONE" in text:
        print("already patched:", path)
        return

    old_ports = """        <devicePort tagName="Built-In Mic" type="AUDIO_DEVICE_IN_BUILTIN_MIC" role="source">
        </devicePort>"""
    new_ports = """        <devicePort tagName="Wired Headset" type="AUDIO_DEVICE_OUT_WIRED_HEADSET" role="sink">
        </devicePort>
        <devicePort tagName="Wired Headphones" type="AUDIO_DEVICE_OUT_WIRED_HEADPHONE" role="sink">
        </devicePort>
        <devicePort tagName="Wired Headset Mic" type="AUDIO_DEVICE_IN_WIRED_HEADSET" role="source">
        </devicePort>
        <devicePort tagName="Built-In Mic" type="AUDIO_DEVICE_IN_BUILTIN_MIC" role="source">
        </devicePort>"""
    if old_ports not in text:
        raise SystemExit("devicePorts anchor not found (Built-In Mic) — unsupported policy layout")
    text = text.replace(old_ports, new_ports, 1)

    old_route = """        <route type="mix" sink="Speaker Safe"
               sources="primary output,raw,deep_buffer,compressed_offload,mmap_no_irq_out,voip_rx"/>"""
    new_route = """        <route type="mix" sink="Speaker Safe"
               sources="primary output,raw,deep_buffer,compressed_offload,mmap_no_irq_out,voip_rx"/>
        <route type="mix" sink="Wired Headset"
               sources="primary output,raw,deep_buffer,compressed_offload,mmap_no_irq_out,voip_rx"/>
        <route type="mix" sink="Wired Headphones"
               sources="primary output,raw,deep_buffer,compressed_offload,mmap_no_irq_out,voip_rx"/>"""
    if old_route not in text:
        # Fallback: insert after Speaker route if Speaker Safe layout differs
        old_route = """        <route type="mix" sink="Speaker"
               sources="primary output,raw,deep_buffer,compressed_offload,mmap_no_irq_out,voip_rx"/>"""
        new_route = """        <route type="mix" sink="Speaker"
               sources="primary output,raw,deep_buffer,compressed_offload,mmap_no_irq_out,voip_rx"/>
        <route type="mix" sink="Wired Headset"
               sources="primary output,raw,deep_buffer,compressed_offload,mmap_no_irq_out,voip_rx"/>
        <route type="mix" sink="Wired Headphones"
               sources="primary output,raw,deep_buffer,compressed_offload,mmap_no_irq_out,voip_rx"/>"""
        if old_route not in text:
            raise SystemExit("Speaker/Speaker Safe route not found — unsupported policy layout")
    text = text.replace(old_route, new_route, 1)

    old_src = 'sources="Built-In Mic,Built-In Back Mic,BT SCO Headset Mic,USB Device In,USB Headset In"'
    new_src = 'sources="Built-In Mic,Built-In Back Mic,Wired Headset Mic,BT SCO Headset Mic,USB Device In,USB Headset In"'
    if old_src in text:
        text = text.replace(old_src, new_src)

    path.write_text(text, encoding="utf-8")
    print("patched:", path)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: patch_policy.py <primary_audio_policy_configuration.xml>")
    patch(Path(sys.argv[1]))
