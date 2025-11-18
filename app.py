from flask import Flask, render_template, request, redirect, url_for, flash, session
import mysql.connector

app = Flask(__name__)
app.secret_key = 'super_secret_key'


db_config = {
    'user': 'root',
    'password': '0523',
    'host': 'localhost',
    'database': 'hotel_project'
}


def get_db_connection():
    return mysql.connector.connect(**db_config)


# Part 1. front page
@app.route('/')
def index():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    # 获取房间列表
    query = """
        SELECT r.room_number, t.type_name, t.price, t.description 
        FROM Rooms r
        JOIN Room_Types t ON r.type_id = t.type_id
        WHERE r.status = 'Available'
    """
    cursor.execute(query)
    rooms = cursor.fetchall()
    conn.close()

    user_name = session.get('user_name')

    return render_template('index.html', rooms=rooms, user_name=user_name)

# Part 2: log in
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        email = request.form['email']
        password = request.form['password']

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        query = "SELECT * FROM Guests WHERE email = %s AND password = %s"
        cursor.execute(query, (email, password))
        user = cursor.fetchone()
        conn.close()

        if user:
            session['user_id'] = user['guest_id']
            session['user_name'] = user['first_name']
            flash('Login successful!', 'success')
            return redirect(url_for('index'))
        else:
            flash('Invalid email or password', 'danger')
            return redirect(url_for('login'))

    return render_template('login.html')

# Part 3: log out
@app.route('/logout')
def logout():
    session.clear()
    flash('You have been logged out.', 'info')
    return redirect(url_for('login'))


if __name__ == '__main__':
    app.run(debug=True)