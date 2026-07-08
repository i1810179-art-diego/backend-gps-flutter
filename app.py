import os
from datetime import datetime

import psycopg2
from psycopg2.extras import RealDictCursor
from flask import Flask, jsonify, request
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

DATABASE_URL = os.environ.get("DATABASE_URL")


def obtener_conexion():
    if not DATABASE_URL:
        raise RuntimeError("No existe la variable DATABASE_URL")

    return psycopg2.connect(DATABASE_URL)


def crear_base_datos():
    conexion = obtener_conexion()
    cursor = conexion.cursor()

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS ubicaciones (
            id SERIAL PRIMARY KEY,
            latitud DOUBLE PRECISION NOT NULL,
            longitud DOUBLE PRECISION NOT NULL,
            precision DOUBLE PRECISION,
            altitud DOUBLE PRECISION,
            velocidad DOUBLE PRECISION,
            rumbo DOUBLE PRECISION,
            marca_tiempo TEXT,
            fecha_registro TIMESTAMP NOT NULL
        )
    """)

    conexion.commit()
    cursor.close()
    conexion.close()


@app.route("/", methods=["GET"])
def inicio():
    return jsonify({
        "mensaje": "Backend GPS funcionando en Render",
        "rutas": {
            "guardar": "POST /api/ubicaciones",
            "listar": "GET /api/ubicaciones"
        }
    })


@app.route("/api/ubicaciones", methods=["POST"])
def guardar_ubicacion():
    try:
        datos = request.get_json(force=True)

        print("JSON RECIBIDO:")
        print(datos)

        if not isinstance(datos, dict):
            return jsonify({
                "error": "No se recibió un objeto JSON válido"
            }), 400

        latitud = (
            datos.get("latitud")
            or datos.get("latitude")
            or datos.get("lat")
        )

        longitud = (
            datos.get("longitud")
            or datos.get("longitude")
            or datos.get("lon")
            or datos.get("lng")
        )

        if latitud is None or longitud is None:
            return jsonify({
                "error": "No se encontraron latitud y longitud",
                "json_recibido": datos
            }), 400

        precision = datos.get("precision")
        if precision is None:
            precision = datos.get("accuracy")

        altitud = datos.get("altitud")
        if altitud is None:
            altitud = datos.get("altitude")

        velocidad = datos.get("velocidad")
        if velocidad is None:
            velocidad = datos.get("speed")

        rumbo = datos.get("rumbo")
        if rumbo is None:
            rumbo = datos.get("heading")

        marca_tiempo = (
            datos.get("marca de tiempo")
            or datos.get("marca_tiempo")
            or datos.get("timestamp")
        )

        conexion = obtener_conexion()
        cursor = conexion.cursor()

        cursor.execute("""
            INSERT INTO ubicaciones (
                latitud,
                longitud,
                precision,
                altitud,
                velocidad,
                rumbo,
                marca_tiempo,
                fecha_registro
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (
            latitud,
            longitud,
            precision,
            altitud,
            velocidad,
            rumbo,
            marca_tiempo,
            datetime.now()
        ))

        nuevo_id = cursor.fetchone()[0]

        conexion.commit()
        cursor.close()
        conexion.close()

        return jsonify({
            "mensaje": "Ubicación guardada correctamente",
            "id": nuevo_id,
            "latitud": latitud,
            "longitud": longitud
        }), 201

    except Exception as error:
        print("ERROR AL GUARDAR:")
        print(error)

        return jsonify({
            "error": str(error)
        }), 500


@app.route("/api/ubicaciones", methods=["GET"])
def listar_ubicaciones():
    try:
        conexion = obtener_conexion()

        cursor = conexion.cursor(
            cursor_factory=RealDictCursor
        )

        cursor.execute("""
            SELECT * 
            FROM ubicaciones
            ORDER BY id DESC
        """)

        ubicaciones = cursor.fetchall()

        cursor.close()
        conexion.close()

        return jsonify({
            "cantidad": len(ubicaciones),
            "ubicaciones": ubicaciones
        })

    except Exception as error:
        return jsonify({
            "error": str(error)
        }), 500


crear_base_datos()