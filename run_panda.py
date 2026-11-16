#!/usr/bin/env python3
import sys
from direct.showbase.ShowBase import ShowBase
from direct.task import Task
from panda3d.core import AmbientLight, DirectionalLight, Vec4, Vec3

class P3PandaApp(ShowBase):
    def __init__(self):
        super().__init__()
        
        # 1. Window properties
        from panda3d.core import WindowProperties
        props = WindowProperties()
        props.setTitle("Panda3D + P3 Engine Model Viewer")
        self.win.requestProperties(props)
        
        # 2. Lighting
        alight = AmbientLight('alight')
        alight.setColor(Vec4(0.3, 0.3, 0.35, 1))
        alnp = self.render.attachNewNode(alight)
        self.render.setLight(alnp)

        dlight = DirectionalLight('dlight')
        dlight.setColor(Vec4(0.9, 0.9, 0.9, 1))
        dlnp = self.render.attachNewNode(dlight)
        dlnp.setHpr(45, -60, 0)
        self.render.setLight(dlnp)

        # 3. Load our 3D Custom Car model
        try:
            self.car = self.loader.loadModel("car_custom.obj")
            self.car.reparentTo(self.render)
            self.car.setScale(1.0, 1.0, 1.0)
            self.car.setPos(0, 10, -1)
            print("[Panda3D] Successfully loaded car_custom.obj!")
        except Exception as e:
            print(f"[Panda3D] Model load note: {e}")
            # Fallback cube if needed
            self.car = self.loader.loadModel("models/box")
            self.car.reparentTo(self.render)
            self.car.setPos(0, 10, 0)

        # 4. Set Camera position
        self.camera.setPos(0, -12, 4)
        self.camera.lookAt(0, 0, 0)

        # 5. Continuous rotation task
        self.taskMgr.add(self.spin_camera_task, "SpinCameraTask")

    def spin_camera_task(self, task):
        angleDegrees = task.time * 25.0
        self.car.setHpr(angleDegrees, 0, 0)
        return Task.cont

if __name__ == "__main__":
    app = P3PandaApp()
    app.run()
