from server.app import app
import logging
from server.logger import logger

if __name__ == '__main__':
    # FOR DEBUG PURPOSE ONLY
    # can switch back to 127.0.0.1:8000
    logging.basicConfig(level=logging.DEBUG, 
                        filename='flask.log', 
                        filemode='a', 
                        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    app.run(host='0.0.0.0', port=8000, debug=True)
